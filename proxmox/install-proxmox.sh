#!/usr/bin/env bash
# Janua™ LXC installer for Proxmox VE
# Copyright 2025-2026 Skylark Software™
# License: GPL-3.0-only
#
# Janua™ and Skylark Software™ are trademarks of Skylark Software.
#
# Creates an unprivileged LXC container running Janua (Apache Guacamole guacd
# with FreeRDP 3) via Docker. Run this script on a Proxmox VE host.
#
# Usage (Forgejo — primary during dev):
#   bash -c "$(wget -qO- https://skylark.labrack.me/apps/forgejo/jbrame/Janua/raw/branch/main/proxmox/install-proxmox.sh)"
#
# Usage (GitHub — once mirrored):
#   bash -c "$(wget -qO- https://raw.githubusercontent.com/Skylark-Software/Janua/main/proxmox/install-proxmox.sh)"

set -euo pipefail

# ---------- Defaults (overridable via environment) ----------
CTID="${CTID:-}"                          # Auto-detect next free ID if empty
CT_HOSTNAME="${CT_HOSTNAME:-janua}"
DISK_GB="${DISK_GB:-8}"
CORES="${CORES:-2}"
RAM_MB="${RAM_MB:-2048}"
SWAP_MB="${SWAP_MB:-512}"
BRIDGE="${BRIDGE:-vmbr0}"
STORAGE="${STORAGE:-local-lvm}"
TEMPLATE_STORAGE="${TEMPLATE_STORAGE:-local}"
OS_TEMPLATE="${OS_TEMPLATE:-debian-12-standard}"
NETWORK_MODE="${NETWORK_MODE:-dhcp}"      # dhcp or static
STATIC_IP="${STATIC_IP:-}"                # e.g. 192.168.1.50/24
STATIC_GW="${STATIC_GW:-}"                # e.g. 192.168.1.1
NAMESERVER="${NAMESERVER:-}"              # optional: override DHCP-provided DNS (space-separated list, e.g. "192.168.1.53 1.1.1.1")
FALLBACK_DNS="${FALLBACK_DNS:-1.1.1.1}"   # used during install only if the container's DNS can't resolve
USE_PREBUILT="${USE_PREBUILT:-no}"        # 'yes' = pull from ghcr.io; 'no' = build locally inside LXC (default until public images land)

# ---------- Colors (ANSI escape literals so they work in both echo -e and cat heredocs) ----------
R=$'\033[0;31m'; G=$'\033[0;32m'; Y=$'\033[1;33m'; B=$'\033[0;34m'; N=$'\033[0m'
info()  { echo -e "${B}[*]${N} $*"; }
ok()    { echo -e "${G}[+]${N} $*"; }
warn()  { echo -e "${Y}[!]${N} $*"; }
die()   { echo -e "${R}[x]${N} $*" >&2; exit 1; }

# ---------- Banner ----------
cat <<'EOF'

     ██╗ █████╗ ███╗   ██╗██╗   ██╗ █████╗
     ██║██╔══██╗████╗  ██║██║   ██║██╔══██╗
     ██║███████║██╔██╗ ██║██║   ██║███████║
██   ██║██╔══██║██║╚██╗██║██║   ██║██╔══██║
╚█████╔╝██║  ██║██║ ╚████║╚██████╔╝██║  ██║
 ╚════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝

 Apache Guacamole + FreeRDP 3  -  Proxmox LXC Installer
EOF
echo

# ---------- Preflight ----------
[[ $EUID -eq 0 ]] || die "Run as root on the Proxmox host."
command -v pveversion >/dev/null 2>&1 || die "pveversion not found. Run this on a Proxmox VE host."
command -v pct >/dev/null 2>&1 || die "pct not found. Is this Proxmox VE?"

PVE_VER=$(pveversion | head -1 | awk -F'/' '{print $2}' | cut -d'-' -f1)
info "Proxmox VE version: $PVE_VER"

# Auto-assign CTID if not provided
if [[ -z "$CTID" ]]; then
    CTID=$(pvesh get /cluster/nextid)
    info "Auto-assigned container ID: $CTID"
fi

# Check CTID isn't in use
if pct status "$CTID" &>/dev/null; then
    die "Container $CTID already exists. Set CTID=<free-id> to choose another."
fi

# ---------- Template ----------
info "Checking for LXC template..."
TEMPLATE_NAME=$(pveam available --section system 2>/dev/null \
    | awk -v t="$OS_TEMPLATE" '$2 ~ t {print $2}' \
    | sort -V | tail -1 || true)

if [[ -z "$TEMPLATE_NAME" ]]; then
    die "No template matching '$OS_TEMPLATE' found. Try: pveam update && pveam available"
fi

LOCAL_TEMPLATE="$TEMPLATE_STORAGE:vztmpl/$TEMPLATE_NAME"
if ! pvesm list "$TEMPLATE_STORAGE" 2>/dev/null | grep -q "$TEMPLATE_NAME"; then
    info "Downloading $TEMPLATE_NAME..."
    pveam update >/dev/null
    pveam download "$TEMPLATE_STORAGE" "$TEMPLATE_NAME"
    ok "Template downloaded."
else
    ok "Template already present: $TEMPLATE_NAME"
fi

# ---------- Network string ----------
if [[ "$NETWORK_MODE" == "static" ]]; then
    [[ -n "$STATIC_IP" && -n "$STATIC_GW" ]] || die "Static mode requires STATIC_IP and STATIC_GW."
    NET_STRING="name=eth0,bridge=$BRIDGE,ip=$STATIC_IP,gw=$STATIC_GW"
else
    NET_STRING="name=eth0,bridge=$BRIDGE,ip=dhcp"
fi

# ---------- Generate root password for LXC ----------
LXC_ROOT_PW=$(openssl rand -base64 24 | tr -d '/+=' | head -c 20)

# ---------- Create container ----------
info "Creating unprivileged LXC $CTID (hostname: $CT_HOSTNAME)..."
PCT_CREATE_ARGS=(
    "$CTID" "$LOCAL_TEMPLATE"
    --hostname "$CT_HOSTNAME"
    --cores "$CORES"
    --memory "$RAM_MB"
    --swap "$SWAP_MB"
    --rootfs "$STORAGE:$DISK_GB"
    --net0 "$NET_STRING"
    --unprivileged 1
    --features "nesting=1,keyctl=1"
    --onboot 1
    --password "$LXC_ROOT_PW"
    --ostype debian
    --tags "janua;guacamole;docker"
)
if [[ -n "$NAMESERVER" ]]; then
    PCT_CREATE_ARGS+=(--nameserver "$NAMESERVER")
    info "Using explicit DNS: $NAMESERVER"
fi
pct create "${PCT_CREATE_ARGS[@]}" >/dev/null

ok "Container created."

# ---------- Start container ----------
info "Starting container..."
pct start "$CTID"

# Wait for L3 connectivity (separate from DNS)
info "Waiting for L3 connectivity..."
for i in {1..30}; do
    if pct exec "$CTID" -- ping -c 1 -W 2 "$FALLBACK_DNS" >/dev/null 2>&1; then
        ok "L3 connectivity OK."
        break
    fi
    sleep 1
    [[ $i -eq 30 ]] && die "Container cannot reach the outside world (tried pinging $FALLBACK_DNS for 30s)."
done

# DNS setup: write resolv.conf explicitly and pin it against DHCP stomping.
# Priority: explicit NAMESERVER env → DHCP-provided (if it resolves) → FALLBACK_DNS
info "Configuring DNS..."
if [[ -n "$NAMESERVER" ]]; then
    DNS_CHOICE="$NAMESERVER"
    info "Using explicit DNS: $DNS_CHOICE"
    pct exec "$CTID" -- bash -c "printf 'nameserver %s\n' $DNS_CHOICE > /etc/resolv.conf"
elif pct exec "$CTID" -- getent hosts download.docker.com >/dev/null 2>&1; then
    DNS_CHOICE=$(pct exec "$CTID" -- awk '/nameserver/{print $2}' /etc/resolv.conf | tr '\n' ' ')
    ok "DHCP-provided DNS is working: $DNS_CHOICE"
else
    DNS_CHOICE="$FALLBACK_DNS"
    warn "DHCP DNS unreachable; falling back to $FALLBACK_DNS (override with NAMESERVER=...)"
    pct exec "$CTID" -- bash -c "echo 'nameserver $FALLBACK_DNS' > /etc/resolv.conf"
fi

# Pin resolv.conf against dhclient renewals. chattr +i works in unprivileged
# LXCs for root-owned files in the container's own userns.
pct exec "$CTID" -- chattr +i /etc/resolv.conf 2>/dev/null && ok "resolv.conf pinned (immutable)." \
    || warn "Could not pin /etc/resolv.conf (chattr). DHCP renewals may revert DNS."

# Verify DNS actually works
if ! pct exec "$CTID" -- getent hosts download.docker.com >/dev/null 2>&1; then
    die "DNS not resolving even after configuration. Check container's outbound UDP:53."
fi
ok "DNS verified."

# Export effective DNS so the inner installer can configure Docker with it.
# Strip whitespace, keep as space-separated.
EFFECTIVE_DNS=$(echo "$DNS_CHOICE" | xargs)

# ---------- Push inner installer and run ----------
# If this script is running from a local file (not curl|bash), prefer the
# inner script sitting next to it — makes dev iteration painless.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
LOCAL_INNER=""
if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/janua-install.sh" ]]; then
    LOCAL_INNER="$SCRIPT_DIR/janua-install.sh"
fi

INNER_URL="${INNER_URL:-https://skylark.labrack.me/apps/forgejo/jbrame/Janua/raw/branch/main/proxmox/janua-install.sh}"

if [[ -n "$LOCAL_INNER" ]]; then
    info "Using local inner installer: $LOCAL_INNER"
    pct push "$CTID" "$LOCAL_INNER" /tmp/janua-install.sh
    pct exec "$CTID" -- bash -c "
        export DEBIAN_FRONTEND=noninteractive
        export USE_PREBUILT='$USE_PREBUILT'
        export INSTALL_DNS='$EFFECTIVE_DNS'
        apt-get update -qq
        apt-get install -y -qq curl ca-certificates >/dev/null
        bash /tmp/janua-install.sh
    "
else
    info "Fetching inner installer from: $INNER_URL"
    pct exec "$CTID" -- bash -c "
        export DEBIAN_FRONTEND=noninteractive
        export USE_PREBUILT='$USE_PREBUILT'
        export INSTALL_DNS='$EFFECTIVE_DNS'
        apt-get update -qq
        apt-get install -y -qq curl ca-certificates >/dev/null
        curl -fsSL '$INNER_URL' | bash
    "
fi

# ---------- Get container IP for final message ----------
CT_IP=$(pct exec "$CTID" -- ip -4 -o addr show eth0 | awk '{print $4}' | cut -d/ -f1 | head -1)

# ---------- Stash install info inside the container instead of printing secrets ----------
pct exec "$CTID" -- bash -c "cat > /root/.janua-install-info <<EOF
# Janua install summary — generated $(date -Iseconds)
LXC_ROOT_PASSWORD=$LXC_ROOT_PW
POSTGRES_PASSWORD_FILE=/opt/janua/.postgres-password
CONTAINER_IP=$CT_IP
WEB_URL=http://$CT_IP:8085/janua
DEFAULT_LOGIN=admin/admin (change immediately)
EOF
chmod 600 /root/.janua-install-info"

# ---------- Final summary — action-oriented for new users ----------
cat <<EOF

${G}════════════════════════════════════════════════════════════════${N}
${G} Janua™ is running. Here are your next 3 steps:${N}
${G}════════════════════════════════════════════════════════════════${N}

 1.  Open in your browser:  ${G}http://$CT_IP:8085/janua${N}
 2.  Log in with:            admin / admin
 3.  Change the password:    ${Y}Settings → Preferences${N}

 When you're ready to add your first remote desktop, see:
 https://github.com/Skylark-Software/Janua/blob/main/docs/FIRST_CONNECTION.md

 ----------------------------------------------------------------
 Container details
   CTID:      $CTID
   Hostname:  $CT_HOSTNAME
   IP:        $CT_IP
   Secrets:   pct exec $CTID -- cat /root/.janua-install-info

 Manage the stack from the Proxmox host:
   pct enter $CTID
   cd /opt/janua
   docker compose ps
   docker compose logs -f
   docker compose pull && docker compose up -d   # update

 For production (real TLS cert, custom hostname): see proxmox/README.md

EOF
