#!/usr/bin/env bash
# Janua™ inner installer - runs inside the LXC container
# Copyright 2025-2026 Skylark Software™
# License: GPL-3.0-only
#
# Janua™ and Skylark Software™ are trademarks of Skylark Software.
#
# Installs Docker Engine, clones Janua, and brings up the stack.
# Called by install-proxmox.sh but can also be run manually inside any
# Debian 12 / 13 container or VM.

set -euo pipefail

USE_PREBUILT="${USE_PREBUILT:-yes}"        # 'yes' pulls guacd from ghcr.io (default); 'no' builds locally
JANUA_IMAGE_TAG="${JANUA_IMAGE_TAG:-latest}" # ghcr tag for the prebuilt guacd (latest = stable, beta = beta channel)
INSTALL_DIR="${INSTALL_DIR:-/opt/janua}"
REPO_URL="${REPO_URL:-https://github.com/Skylark-Software/Janua.git}"
BRANCH="${BRANCH:-main}"

R=$'\033[0;31m'; G=$'\033[0;32m'; Y=$'\033[1;33m'; B=$'\033[0;34m'; N=$'\033[0m'
info()  { echo -e "${B}[*]${N} $*"; }
ok()    { echo -e "${G}[+]${N} $*"; }
warn()  { echo -e "${Y}[!]${N} $*"; }
die()   { echo -e "${R}[x]${N} $*" >&2; exit 1; }

export DEBIAN_FRONTEND=noninteractive
# Fresh LXC templates ship no generated locales; C.UTF-8 avoids a wall of
# perl/apt locale warnings without pulling in the locales package.
export LC_ALL=C.UTF-8 LANG=C.UTF-8

# ---------- Base packages ----------
info "Installing base packages..."
apt-get update -qq
apt-get install -y -qq \
    ca-certificates curl git openssl gnupg lsb-release \
    >/dev/null
ok "Base packages installed."

# ---------- Docker Engine ----------
if ! command -v docker >/dev/null 2>&1; then
    info "Installing Docker Engine..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg \
        -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    . /etc/os-release
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/debian $VERSION_CODENAME stable" \
        > /etc/apt/sources.list.d/docker.list

    apt-get update -qq
    apt-get install -y -qq \
        docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin \
        >/dev/null
    systemctl enable --now docker >/dev/null 2>&1 || true
    ok "Docker installed: $(docker --version)"
else
    ok "Docker already installed: $(docker --version)"
fi

# ---------- Pin DNS against DHCP renewals ----------
# Unprivileged LXCs can't chattr +i. And a running dhclient won't re-read
# dhclient.conf after its initial bind — so a `supersede` directive only
# helps new dhclient invocations, not the one that's already bound. The
# bulletproof fix is an enter-hook that overrides make_resolv_conf() to
# a no-op, which dhclient sources on every lease event.
INSTALL_DNS="${INSTALL_DNS:-$(awk '/nameserver/{print $2}' /etc/resolv.conf | xargs)}"
INSTALL_DNS="${INSTALL_DNS:-1.1.1.1}"

DNS_CSV=$(echo "$INSTALL_DNS" | tr -s ' ' | sed 's/ /, /g')
info "Pinning DNS (hook override + supersede): $DNS_CSV"

# 1) Hook override — prevents dhclient from touching resolv.conf on any event
mkdir -p /etc/dhcp/dhclient-enter-hooks.d
cat > /etc/dhcp/dhclient-enter-hooks.d/zzz-no-resolv-update <<'HOOK'
#!/bin/sh
# Janua installer: DNS is managed explicitly; don't let dhclient overwrite it.
make_resolv_conf() { :; }
HOOK
chmod +x /etc/dhcp/dhclient-enter-hooks.d/zzz-no-resolv-update

# 2) Supersede directive (belt-and-suspenders for any future dhclient restart)
if [[ -f /etc/dhcp/dhclient.conf ]]; then
    sed -i '/^supersede domain-name-servers /d' /etc/dhcp/dhclient.conf
    echo "supersede domain-name-servers $DNS_CSV;" >> /etc/dhcp/dhclient.conf
fi

# 3) Write the resolv.conf we want. Now DHCP renewals won't clobber it.
echo "$INSTALL_DNS" | tr ' ' '\n' | awk 'NF{print "nameserver " $0}' > /etc/resolv.conf
ok "DNS pinned."

# ---------- Configure Docker's DNS explicitly ----------
# Docker build/run containers get their /etc/resolv.conf from the daemon.
# Setting `dns:` in daemon.json guarantees build steps resolve correctly
# regardless of what's in the host's /etc/resolv.conf at build time.
DNS_JSON=$(echo "$INSTALL_DNS" | tr ' ' '\n' | awk 'NF{printf "\"%s\",", $0}' | sed 's/,$//')
info "Configuring Docker daemon DNS: $INSTALL_DNS"
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "dns": [${DNS_JSON}]
}
EOF
systemctl restart docker
# Give daemon a moment to come back
for i in {1..15}; do
    docker info >/dev/null 2>&1 && break
    sleep 1
done

# ---------- Verify Docker can actually run (catches LXC nesting issues) ----------
info "Verifying Docker runtime..."
if ! docker run --rm hello-world >/dev/null 2>&1; then
    warn "Docker hello-world failed. If running in LXC, ensure the container"
    warn "has features: nesting=1,keyctl=1 set on the Proxmox host."
    die  "Docker runtime check failed."
fi
ok "Docker runtime OK."

# Verify DNS works from inside a throwaway container (matches what 'docker build' sees)
info "Verifying DNS from within a Docker build container..."
if ! docker run --rm alpine:latest nslookup github.com >/dev/null 2>&1; then
    die "Docker build containers cannot resolve github.com. Docker daemon DNS config: $INSTALL_DNS"
fi
ok "Docker-network DNS OK."

# ---------- Clone or update Janua ----------
if [[ -d "$INSTALL_DIR/.git" ]]; then
    info "Updating existing Janua checkout at $INSTALL_DIR..."
    git -C "$INSTALL_DIR" fetch --quiet origin
    git -C "$INSTALL_DIR" reset --hard "origin/$BRANCH" --quiet
else
    info "Cloning Janua into $INSTALL_DIR..."
    mkdir -p "$(dirname "$INSTALL_DIR")"
    git clone --branch "$BRANCH" --depth 1 "$REPO_URL" "$INSTALL_DIR" --quiet
fi
cd "$INSTALL_DIR"
ok "Janua source ready at $INSTALL_DIR"

# ---------- Generate or load postgres password ----------
PW_FILE="$INSTALL_DIR/.postgres-password"
if [[ ! -f "$PW_FILE" ]]; then
    openssl rand -base64 32 | tr -d '/+=' | head -c 32 > "$PW_FILE"
    chmod 600 "$PW_FILE"
    ok "Generated postgres password -> $PW_FILE"
else
    ok "Using existing postgres password from $PW_FILE"
fi
POSTGRES_PASSWORD=$(cat "$PW_FILE")
export POSTGRES_PASSWORD

# ---------- Write .env for docker compose ----------
cat > "$INSTALL_DIR/.env" <<EOF
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
JANUA_IMAGE_TAG=$JANUA_IMAGE_TAG
EOF
chmod 600 "$INSTALL_DIR/.env"

# ---------- Select build vs pre-built path via compose override ----------
# Docker Compose auto-merges ./docker-compose.override.yml if present.
# USE_PREBUILT=yes  → drop in the prebuilt override (pulls from ghcr.io, skips build)
# USE_PREBUILT=no   → remove any override, use base compose file (local build)
OVERRIDE_SRC="$INSTALL_DIR/proxmox/docker-compose.prebuilt.yml"
OVERRIDE_DST="$INSTALL_DIR/docker-compose.override.yml"

if [[ "$USE_PREBUILT" == "yes" ]]; then
    if [[ -f "$OVERRIDE_SRC" ]]; then
        info "Using pre-built images from ghcr.io (override: $OVERRIDE_SRC)"
        cp "$OVERRIDE_SRC" "$OVERRIDE_DST"
    else
        warn "USE_PREBUILT=yes requested but $OVERRIDE_SRC missing; falling back to local build."
        USE_PREBUILT=no
    fi
else
    [[ -f "$OVERRIDE_DST" ]] && rm -f "$OVERRIDE_DST"
fi

# ---------- Bring up the stack ----------
if [[ "$USE_PREBUILT" == "yes" ]]; then
    info "Pulling images (this can take a few minutes on first run)..."
    docker compose pull 2>&1 | grep -vE '^$' || true
else
    info "Building images locally (first run takes several minutes)..."
    docker compose build 2>&1 | tail -20 || die "Image build failed; see output above."
fi

info "Starting Janua stack..."
docker compose up -d

# ---------- Wait for web UI ----------
info "Waiting for web UI to respond..."
for i in {1..60}; do
    if curl -fsS -o /dev/null -w '%{http_code}' http://127.0.0.1:8085/janua/ 2>/dev/null \
        | grep -qE '^(200|302|401)$'; then
        ok "Web UI is responding."
        break
    fi
    sleep 2
    [[ $i -eq 60 ]] && warn "Web UI didn't respond in time. Check 'docker compose logs'."
done

# ---------- systemd service for auto-restart on boot ----------
info "Installing systemd unit for stack auto-start..."
cat > /etc/systemd/system/janua.service <<EOF
[Unit]
Description=Janua (Apache Guacamole + FreeRDP 3) Docker stack
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$INSTALL_DIR
EnvironmentFile=$INSTALL_DIR/.env
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable janua.service >/dev/null 2>&1
ok "janua.service enabled."

# ---------- Summary ----------
CT_IP=$(ip -4 -o addr show eth0 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -1)
CT_IP="${CT_IP:-<container-ip>}"

cat <<EOF

$(echo -e "${G}")================================================================$(echo -e "${N}")
 Janua™ is running.

   Web UI:          http://$CT_IP:8085/janua
   Default login:   admin / admin  (change this immediately)
   Install dir:     $INSTALL_DIR
   Postgres pw:     $INSTALL_DIR/.postgres-password

 Manage:
   cd $INSTALL_DIR
   docker compose ps
   docker compose logs -f
   docker compose pull && docker compose up -d

$(echo -e "${G}")================================================================$(echo -e "${N}")

EOF
