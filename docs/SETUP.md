# Janua Comprehensive Setup Guide

This guide walks through setting up Janua from scratch, including prerequisites and detailed configuration steps. For a quick start, see the [README](../README.md#quick-start).

## Prerequisites

### On the Server (where Janua runs)

**Docker and Docker Compose**

Janua runs as a set of Docker containers. You'll need:

- Docker Engine 20.10 or later
- Docker Compose v2 (comes with Docker Desktop, or install separately on Linux)

**Ubuntu/Debian:**
```bash
# Install Docker
curl -fsSL https://get.docker.com | sh

# Add your user to the docker group (logout/login required)
sudo usermod -aG docker $USER

# Verify installation
docker --version
docker compose version
```

**Fedora:**
```bash
sudo dnf install docker docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
```

**Arch Linux:**
```bash
sudo pacman -S docker docker-compose
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
```

### On the Target Machine (remote desktop you want to access)

- Linux with GNOME 48+ (Fedora 42, Ubuntu 25.04+) or KDE Plasma with KRdp
- Or Windows with Remote Desktop enabled
- Or xrdp on any Linux distribution

## Installation

### Step 1: Download Janua

```bash
git clone https://github.com/skylarksoftware/janua.git
cd janua
```

Or download the ZIP from GitHub and extract it.

### Step 2: Configure the Database Password

The PostgreSQL database needs a password. Set it as an environment variable:

```bash
export POSTGRES_PASSWORD="your-secure-password-here"
```

For production, add this to your shell profile (`~/.bashrc` or `~/.zshrc`) or use a `.env` file:

```bash
# Create a .env file (don't commit this to git!)
echo 'POSTGRES_PASSWORD=your-secure-password-here' > .env
```

### Step 3: Start Janua

```bash
docker compose up -d
```

This builds and starts three containers:
- **janua-guacd** - The custom guacd with FreeRDP 3 support
- **guacamole** - The official Guacamole web application
- **postgres** - The PostgreSQL database

First startup takes a few minutes while images download.

### Step 4: Verify Everything is Running

```bash
docker compose ps
```

You should see all three services with "Up" status.

### Step 5: Access the Web Interface

Open your browser to: `http://localhost:8085/guacamole`

Default login:
- Username: `guacadmin`
- Password: `guacadmin`

**Important:** Change this password immediately in Settings > Preferences.

## Configuring Remote Desktop Targets

### GNOME Remote Desktop (Fedora 42, Ubuntu 25.04+)

GNOME Remote Desktop (GRD) is built into modern GNOME desktops. Run these commands on the target machine:

**1. Enable RDP:**
```bash
grdctl rdp enable
```

**2. Set credentials:**
```bash
grdctl rdp set-credentials YOUR_USERNAME YOUR_PASSWORD
```

**3. Disable view-only mode:**
```bash
grdctl rdp disable-view-only
```

**4. Generate and set TLS certificate (required):**
```bash
openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
    -subj "/CN=$(hostname)" \
    -keyout /tmp/rdp-tls.key -out /tmp/rdp-tls.crt

grdctl rdp set-tls-cert /tmp/rdp-tls.crt
grdctl rdp set-tls-key /tmp/rdp-tls.key

# Clean up temp files
rm /tmp/rdp-tls.key /tmp/rdp-tls.crt
```

**5. (Optional) Disable screen lock for unattended access:**
```bash
gsettings set org.gnome.desktop.screensaver lock-enabled false
gsettings set org.gnome.desktop.session idle-delay 0
```

**6. Verify setup:**
```bash
grdctl status --show-credentials
```

### KDE Plasma KRdp (Fedora 42+ KDE)

KDE uses KRdp for remote desktop. Configure it through System Settings:

1. Open **System Settings** > **Remote Desktop**
2. Enable "Allow remote connections"
3. Set your password
4. Note: KRdp listens on port 3389 by default

### Windows Remote Desktop

1. Open **Settings** > **System** > **Remote Desktop**
2. Enable Remote Desktop
3. Note the PC name or IP address
4. Ensure the user account has a password set

### xrdp (Any Linux)

Install and configure xrdp:

```bash
# Ubuntu/Debian
sudo apt install xrdp
sudo systemctl enable --now xrdp

# Fedora
sudo dnf install xrdp
sudo systemctl enable --now xrdp
```

## Adding Connections in Guacamole

1. Log into Guacamole web interface
2. Go to **Settings** > **Connections**
3. Click **New Connection**
4. Configure:
   - **Name:** Descriptive name (e.g., "My Workstation")
   - **Protocol:** RDP
   - **Hostname:** IP address or hostname of target
   - **Port:** 3389 (default RDP port)
   - **Username:** Your remote username
   - **Password:** Your remote password
   - **Security mode:** Any (let it negotiate)
   - **Ignore server certificate:** Check this for self-signed certs

5. For audio support (GNOME Remote Desktop):
   - Scroll to **Device Redirection**
   - Check **Enable audio**

6. Click **Save**

## Testing Your Connection

1. Go to **Home** in Guacamole
2. Click on your connection
3. You should see the remote desktop in your browser

## Firewall Configuration

Ensure these ports are accessible:

| Port | Service | Direction |
|------|---------|-----------|
| 8085 | Guacamole web | Inbound to Janua server |
| 3389 | RDP | Janua server to target machines |

**On the Janua server (if using firewalld):**
```bash
sudo firewall-cmd --add-port=8085/tcp --permanent
sudo firewall-cmd --reload
```

**On target machines:**
```bash
sudo firewall-cmd --add-service=rdp --permanent
sudo firewall-cmd --reload
```

## Updating Janua

To update to the latest version:

```bash
cd janua
git pull
docker compose pull
docker compose up -d
```

## Stopping Janua

```bash
docker compose down
```

To also remove the database (start fresh):
```bash
docker compose down -v
```

## Data Locations

| Path | Purpose |
|------|---------|
| `./postgres-data/` | Database files (connections, users, etc.) |
| `./drive/` | Shared drive for file transfers |
| `./record/` | Session recordings |
| `./guacamole-home/` | Extensions and configuration |

Back up `postgres-data/` to preserve your configuration.

## Next Steps

- [Troubleshooting Guide](../README.md#troubleshooting) - Common issues and solutions
- [Technical Details](../README.md#technical-details) - How Janua patches work
- [Contributing](../CONTRIBUTING.md) - Help improve Janua
