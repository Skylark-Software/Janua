# Janua™ for Proxmox VE

Deploy Janua™ as an LXC container on Proxmox VE. This is an alternate
distribution for users who prefer Proxmox over running Docker on a bare host.

*Janua™ and Skylark Software™ are trademarks of Skylark Software.*

## Quick start

Run on your Proxmox VE host as root. Pick the mirror closest to you:

**Forgejo (primary during development):**
```bash
bash -c "$(wget -qO- https://skylark.labrack.me/apps/forgejo/jbrame/Janua/raw/branch/main/proxmox/install-proxmox.sh)"
```

**GitHub (once mirrored):**
```bash
bash -c "$(wget -qO- https://raw.githubusercontent.com/Skylark-Software/Janua/main/proxmox/install-proxmox.sh)"
```

The script will:

1. Download the Debian 12 LXC template if needed
2. Create an unprivileged container with Docker-in-LXC features enabled (`nesting=1,keyctl=1`)
3. Install Docker Engine inside the container
4. Clone Janua and bring up the stack with a randomly generated Postgres password
5. Install a systemd unit so the stack survives reboots
6. Stash install secrets at `/root/.janua-install-info` inside the container (mode 600)

Default resources: 2 cores, 2 GB RAM, 8 GB disk, DHCP on `vmbr0`, local build
of images (no external registry pulls).

## Customising

Override any default by exporting an environment variable before running:

```bash
export CTID=210                          # Container ID (default: next free)
export CT_HOSTNAME=janua                 # LXC hostname (note: CT_HOSTNAME, not HOSTNAME — bash built-in)
export CORES=4
export RAM_MB=4096
export DISK_GB=16
export BRIDGE=vmbr1
export STORAGE=local-zfs
export NETWORK_MODE=static               # or 'dhcp' (default)
export STATIC_IP=192.168.1.50/24
export STATIC_GW=192.168.1.1
export NAMESERVER="192.168.1.53 1.1.1.1" # override DHCP-provided DNS (space-separated); persists in container
export FALLBACK_DNS=1.1.1.1              # used only during install if container DNS can't resolve (default: 1.1.1.1)
export USE_PREBUILT=no                   # 'no' (default) = build locally; 'yes' = pull from ghcr.io
```

Then run the installer as above.

**`USE_PREBUILT` note:** defaults to `no` until the ghcr.io image pipeline is
published publicly. Flipping to `yes` activates the `docker-compose.prebuilt.yml`
override and pulls images instead of building.

## Why LXC?

An unprivileged LXC with `nesting=1,keyctl=1` runs Docker natively with almost
no overhead compared to a VM, and is the idiomatic way to run containerised
workloads on Proxmox. `guacd`'s `network_mode: host` still works correctly
because it's scoped to the LXC's own network namespace.

## Accessing Janua

After install, the script prints the container IP. Open:

```
http://<container-ip>:8085/janua
```

Default credentials: `admin` / `admin` — **change these immediately**.

## Production: put it behind a reverse proxy with TLS

The LXC only serves plain HTTP on port 8085. For anything non-dev, front it
with Caddy / nginx / Traefik on another host and terminate TLS there. Example
Caddy block:

```caddy
janua.example.com {
    tls {
        dns cloudflare {env.CF_API_TOKEN}
    }
    reverse_proxy http://<container-ip>:8085
}
```

Point a DNS record (public or internal-only via your resolver) at whichever
machine runs the reverse proxy, and let it issue a real Let's Encrypt cert.

## Managing the stack

Enter the container and use `docker compose` as normal:

```bash
pct enter <CTID>
cd /opt/janua
docker compose ps
docker compose logs -f guacd
docker compose pull && docker compose up -d    # update
```

## Retrieving install secrets

The installer does not print the LXC root password to stdout. To retrieve it:

```bash
pct exec <CTID> -- cat /root/.janua-install-info
pct exec <CTID> -- cat /opt/janua/.postgres-password
```

## Uninstalling

On the Proxmox host:

```bash
pct stop <CTID>
pct destroy <CTID>
```

## Running the inner installer manually

If you already have a Debian 12 / 13 VM or LXC and just want the Janua stack:

```bash
curl -fsSL https://skylark.labrack.me/apps/forgejo/jbrame/Janua/raw/branch/main/proxmox/janua-install.sh | bash
```

## Distribution channels

- **Forgejo** (`skylark.labrack.me`) — primary source of truth during development
- **GitHub** (`Skylark-Software/Janua`) — mirror, populated when the script is ready for public release
- **community-scripts.org** — submission planned once the Forgejo path is battle-tested
