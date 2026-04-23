# Janua Comprehensive Setup Guide

This guide walks through setting up Janua from scratch, including prerequisites and detailed configuration steps. For a quick start, see the [README](https://github.com/Skylark-Software/Janua/blob/main/README.md#quick-start).

Janua can be installed two ways:

- [**Method A — Proxmox VE (LXC)**](#method-a--proxmox-ve-lxc-one-command-install) — recommended if you have a Proxmox host. One command, no manual Docker setup.
- [**Method B — Docker on any Linux host**](#method-b--docker-on-any-linux-host) — the standard path for non-Proxmox users. Offers a choice between a pre-built image (fast) and a local build (slower, but you can verify the patches yourself).

Both methods land you at the same place: [Configuring Remote Desktop Targets](#configuring-remote-desktop-targets).

## Method A — Proxmox VE (LXC), one-command install

**If you have access to a Proxmox VE server, this is the simplest path.** The installer creates an unprivileged LXC container, installs Docker inside, and starts Janua automatically — you don't need to configure Docker on the host.

From a Proxmox host shell — the web console at `https://your-proxmox:8006` works (click your node in the left tree, then **Shell**) — run this as root:

```
bash -c "$(wget -qO- https://raw.githubusercontent.com/Skylark-Software/Janua/main/proxmox/install-proxmox.sh)"
```

> If you'd rather review the installer before running it, download [`install-proxmox.sh`](https://github.com/Skylark-Software/Janua/blob/main/proxmox/install-proxmox.sh) first, read through it, then run it locally.

When it finishes, it prints a URL like `http://192.168.1.42:8085/janua`. Open it in your browser and log in with `admin` / `admin`. Change the password from **Settings → Preferences** after logging in.

That's it — skip ahead to [Configuring Remote Desktop Targets](#configuring-remote-desktop-targets) to connect to your first machine.

See [proxmox/README.md](https://github.com/Skylark-Software/Janua/blob/main/proxmox/README.md) for customisation options (container resources, static IP, explicit DNS, etc.).

## Method B — Docker on any Linux host

This is the manual path: install Docker, clone the repo, choose between a pre-built image and a local build, and bring up the compose stack.

### Prerequisites

#### On the server (where Janua runs)

**Docker and Docker Compose**

Janua runs as a set of Docker containers. You'll need:

* Docker Engine 20.10 or later
* Docker Compose v2 (comes with Docker Desktop, or install separately on Linux)

The quick-install commands below use the convenience scripts and distro packages. If you prefer a vetted manual install, see [Docker's official install docs](https://docs.docker.com/engine/install/).

**Ubuntu/Debian:**

```
# Install Docker
curl -fsSL https://get.docker.com | sh

# Add your user to the docker group (logout/login required)
sudo usermod -aG docker $USER

# Verify installation
docker --version
docker compose version
```

**Fedora:**

```
sudo dnf install docker docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
```

**Arch Linux:**

```
sudo pacman -S docker docker-compose
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
```

#### On the target machine (remote desktop you want to access)

* Linux with GNOME 48+ (Fedora 42, Ubuntu 25.04+) or KDE Plasma with KRdp
* Or Windows with Remote Desktop enabled
* Or xrdp on any Linux distribution

### Installation

#### Step 1: Download Janua

Clone with git:

```
git clone https://github.com/Skylark-Software/Janua.git
cd Janua
```

Or [download the latest ZIP](https://github.com/Skylark-Software/Janua/archive/refs/heads/main.zip) and extract it.

#### Step 2: Configure the database password

The PostgreSQL database needs a password. The recommended way is a `.env` file in the repo root — Docker Compose loads it automatically. There's a `.env.example` in the repo you can copy as a starting point:

```
cp .env.example .env
# then edit .env and set a strong POSTGRES_PASSWORD
```

Or create one directly:

```
echo 'POSTGRES_PASSWORD=your-secure-password-here' > .env
```

Use a long, random password — this database holds your connection list, usernames, and (encrypted) credentials. A throwaway like `changeme` defeats the point. Don't commit `.env` to git (the repo's `.gitignore` already excludes it).

If you'd rather pass the password per-invocation, you can instead `export` it in your current shell:

```
export POSTGRES_PASSWORD="your-secure-password-here"
```

#### Step 3: Choose a guacd image — pre-built or local build

The repo's `docker-compose.yml` builds the custom `guacd` container from source by default. Source builds take several minutes (compiling FreeRDP 3 plus the patches) but let you inspect and modify the patches yourself. A pre-built image is published to GitHub Container Registry for people who just want to run Janua.

**Option A — Pre-built image from GHCR (recommended for most users)**

The published image is `ghcr.io/skylark-software/janua` and is **linux/amd64 only**. If you're on arm64 or another architecture, use Option B.

Edit `docker-compose.yml` and replace the `guacd` service's `build:` block with an `image:` reference:

```
services:
  guacd:
    image: ghcr.io/skylark-software/janua:latest
```

Available tags: `:latest` (recommended) and `:main` (tracks the `main` branch head — use this if you specifically want main-branch builds rather than tagged releases). You can also pin to a digest for reproducibility — see the [package page](https://github.com/Skylark-Software/Janua/pkgs/container/janua) for the current SHA.

Then pull it:

```
docker compose pull guacd
```

**Option B — Build from source (default)**

Leave `docker-compose.yml` as-is. The first `docker compose up -d` will build the image locally. Expect several minutes on first run; rebuilds are cached. Choose this if you're on arm64 or another non-amd64 architecture, or if you want to verify the patches or modify them.

You can also build just the guacd image ahead of time:

```
docker build -t janua ./guacd
```

#### Step 4: Start Janua

```
docker compose up -d
```

This starts three containers:

* **guacd** — the custom guacd with FreeRDP 3 support (either built locally or pulled from GHCR, depending on your choice in Step 3). Runs with `network_mode: host`, so port 4822 is exposed on the host itself.
* **guacamole** — the Janua web frontend (rebranded Guacamole), published on host port **8085**.
* **postgres** — the PostgreSQL database.

If you chose the pre-built image, first startup is fast (just the image pulls). If you chose the local build, expect several minutes on the initial run while `guacd` compiles. If you need to change the host port, edit the `ports:` mapping for the `guacamole` service in `docker-compose.yml`.

#### Step 5: Verify everything is running

```
docker compose ps
```

You should see all three services with "Up" status.

#### Step 6: Access the web interface

Open your browser to: `http://localhost:8085/janua`

Default login:

* Username: `admin`
* Password: `admin`

**Important:** Change this password immediately in **Settings → Preferences**.

## Configuring Remote Desktop Targets

### GNOME Remote Desktop (Fedora 42, Ubuntu 25.04+)

GNOME Remote Desktop (GRD) is built into modern GNOME desktops. The `grdctl` CLI used below ships with GNOME 46 and later, so GNOME 48+ targets are covered. On older GNOME versions, configure RDP through **Settings → Sharing** in the GUI instead.

Note: Ubuntu 24.04's GRD 46 has a [known PipeWire threading bug](https://gitlab.gnome.org/GNOME/gnome-remote-desktop/-/issues/182) that breaks audio capture. Video works, but for audio you need GNOME 48+ (Fedora 42, Ubuntu 25.04+).

Run these commands on the target machine:

**1. Enable RDP:**

```
grdctl rdp enable
```

**2. Set credentials:**

```
grdctl rdp set-credentials YOUR_USERNAME YOUR_PASSWORD
```

**3. Disable view-only mode:**

```
grdctl rdp disable-view-only
```

**4. Generate and set TLS certificate (required):**

```
openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
    -subj "/CN=$(hostname)" \
    -keyout /tmp/rdp-tls.key -out /tmp/rdp-tls.crt

grdctl rdp set-tls-cert /tmp/rdp-tls.crt
grdctl rdp set-tls-key /tmp/rdp-tls.key

# Clean up temp files (grdctl stores its own copy)
rm /tmp/rdp-tls.key /tmp/rdp-tls.crt
```

**5. (Optional) Disable screen lock for unattended access:**

Screen lock matters for more than convenience — audio capture through GRD won't start until the session is unlocked.

```
gsettings set org.gnome.desktop.screensaver lock-enabled false
gsettings set org.gnome.desktop.session idle-delay 0
```

**6. Verify setup:**

```
grdctl status --show-credentials
```

### KDE Plasma KRdp (Fedora 42+ KDE)

KDE uses KRdp for remote desktop. Configure it through System Settings:

1. Open **System Settings → Remote Desktop**
2. Enable "Allow remote connections"
3. Set your password
4. Note: KRdp listens on port 3389 by default

### Windows Remote Desktop

1. Open **Settings → System → Remote Desktop**
2. Enable Remote Desktop
3. Note the PC name or IP address
4. Ensure the user account has a password set

### xrdp (any Linux)

Install and configure xrdp:

```
# Ubuntu/Debian
sudo apt install xrdp
sudo systemctl enable --now xrdp

# Fedora
sudo dnf install xrdp
sudo systemctl enable --now xrdp
```

## Adding Connections in Guacamole

1. Log into the Janua web interface
2. Go to **Settings → Connections**
3. Click **New Connection**
4. Configure:

   * **Name:** descriptive name (e.g., "My Workstation")
   * **Protocol:** RDP
   * **Hostname:** IP address or hostname of target
   * **Port:** 3389 (default RDP port)
   * **Username:** your remote username
   * **Password:** your remote password
   * **Security mode:** Any (let it negotiate) — except Windows Server 2022, which needs `security=nla` explicitly
   * **Ignore server certificate:** check this for self-signed certs
5. For audio support (GNOME Remote Desktop):

   * Scroll to **Device Redirection**
   * Check **Enable audio**
6. Click **Save**

## Testing Your Connection

1. Go to **Home** in the Janua web UI
2. Click on your connection
3. You should see the remote desktop in your browser

## Firewall Configuration

Ensure these ports are accessible:

| Port | Service            | Direction                          |
| ---- | ------------------ | ---------------------------------- |
| 8085 | Janua web frontend | Inbound to Janua server            |
| 4822 | guacd (host mode)  | Local only — do not expose         |
| 3389 | RDP                | Janua server to target machines    |

The `guacd` service uses `network_mode: host`, so port 4822 binds directly on the host. It should stay bound to localhost / an internal interface — only `guacamole` needs to reach it, and exposing it publicly gives anyone who can reach it arbitrary RDP from your server.

**On the Janua server — firewalld (Fedora, RHEL):**

```
sudo firewall-cmd --add-port=8085/tcp --permanent
sudo firewall-cmd --reload
```

**On the Janua server — ufw (Ubuntu, Debian):**

```
sudo ufw allow 8085/tcp
```

**On target machines (firewalld):**

```
sudo firewall-cmd --add-service=rdp --permanent
sudo firewall-cmd --reload
```

**On target machines (ufw):**

```
sudo ufw allow 3389/tcp
```

## Updating Janua

To update to the latest version:

```
cd Janua
git pull
docker compose pull
docker compose up -d
```

If you're using the pre-built image, `docker compose pull` fetches the newest `ghcr.io/skylark-software/janua:latest`. If you're building locally, add `--build` to the `up` command to force a rebuild against the latest source:

```
docker compose up -d --build
```

## Stopping Janua

```
docker compose down
```

To also remove the database (start fresh):

```
docker compose down -v
```

## Data Locations

| Path               | Purpose                                   |
| ------------------ | ----------------------------------------- |
| `./postgres-data/` | Database files (connections, users, etc.) |
| `./drive/`         | Shared drive for file transfers           |
| `./record/`        | Session recordings                        |
| `./guacamole-home/`| Extensions and configuration              |

### Backing up your configuration

Don't just `cp -r postgres-data/` while the stack is running — Postgres may be mid-write and you'll get an inconsistent snapshot that won't restore cleanly. Use one of these instead:

**Offline snapshot (simple, requires downtime):**

```
docker compose down
tar czf janua-backup-$(date +%F).tar.gz postgres-data/ guacamole-home/ drive/
docker compose up -d
```

**Live logical backup (no downtime, recommended):**

```
docker compose exec -T postgres \
    pg_dump -U guacamole guacamole_db | gzip > janua-db-$(date +%F).sql.gz
```

Restore with `gunzip -c janua-db-*.sql.gz | docker compose exec -T postgres psql -U guacamole guacamole_db` into a fresh stack.

## Next Steps

* [Troubleshooting Guide](https://github.com/Skylark-Software/Janua/blob/main/README.md#troubleshooting) — common issues and solutions
* [Technical Details](https://github.com/Skylark-Software/Janua/blob/main/README.md#technical-details) — how Janua patches work
* [Contributing](https://github.com/Skylark-Software/Janua/blob/main/CONTRIBUTING.md) — help improve Janua
