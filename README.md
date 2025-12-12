# Janua

A custom Apache Guacamole guacd build with FreeRDP 3 support, enabling full compatibility with GNOME Remote Desktop (GRD) on Wayland, including audio redirection.

**Janua** - Latin for "door" or "gateway"

## Why Janua?

The official Apache Guacamole 1.6.0 guacd uses FreeRDP 2.x, which has two major limitations with modern RDP servers:

1. **No GFX Pipeline Extension** - GNOME Remote Desktop requires the Graphics Pipeline Extension (RDPGFX) which is only available in FreeRDP 3.x
2. **RDPSND Protocol Version 6** - GNOME Remote Desktop expects RDPSND version 8; version 6 causes audio channel negotiation to fail

Janua solves these problems by:
- Building guacd against FreeRDP 3.10.3
- Patching guacamole-server to advertise RDPSND version 8
- Enabling H.264/AVC codecs for RDPGFX (required by KDE KRdp)

## Features

- **FreeRDP 3.x support** with full GFX Pipeline Extension
- **H.264/AVC codec support** for KDE KRdp and modern RDP servers
- **Audio redirection** working with GNOME Remote Desktop
- **RDPSND version 8** patch for modern RDP servers
- **PipeWire support** in FreeRDP build
- **Drop-in replacement** for official guacd image
- **Browser audio fix** extension for AudioContext autoplay restrictions

## Compatibility

| Target | Video | Audio | Notes |
|--------|-------|-------|-------|
| KDE Plasma KRdp | ✅ | ✅ | Requires H.264/AVC support (Janua 2.0+) |
| GNOME Remote Desktop (GNOME 48+) | ✅ | ✅ | Fedora 42, Ubuntu 25.04+ |
| GNOME Remote Desktop (GNOME 46) | ✅ | ❌ | Ubuntu 24.04 - GRD has PipeWire threading bug |
| xrdp | ✅ | ✅ | Full compatibility |
| Windows RDP | ✅ | ✅ | Full compatibility |

**Note:** Ubuntu 24.04's GNOME Remote Desktop (GRD 46.3) has a [known PipeWire threading issue](https://gitlab.gnome.org/GNOME/gnome-remote-desktop/-/issues/182) that prevents audio capture. This is fixed in GNOME 48 (Fedora 42, Ubuntu 25.04+).

## Quick Start

1. Clone the repository:
   ```bash
   git clone https://github.com/skylarksoftware/janua.git
   cd janua
   ```

2. Set a secure database password:
   ```bash
   export POSTGRES_PASSWORD="your-secure-password"
   ```

3. Start the stack:
   ```bash
   docker-compose up -d
   ```

4. Access Guacamole at `http://localhost:8085/guacamole`

   Default credentials: `guacadmin` / `guacadmin`

## Setting Up GNOME Remote Desktop

On your GNOME Wayland target machine:

1. Enable RDP sharing:
   ```bash
   grdctl rdp enable
   grdctl rdp set-credentials USERNAME PASSWORD
   grdctl rdp disable-view-only
   ```

2. Generate TLS certificate (required):
   ```bash
   openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
       -subj "/CN=$(hostname)" \
       -keyout /tmp/rdp-tls.key -out /tmp/rdp-tls.crt
   grdctl rdp set-tls-cert /tmp/rdp-tls.crt
   grdctl rdp set-tls-key /tmp/rdp-tls.key
   rm /tmp/rdp-tls.key /tmp/rdp-tls.crt
   ```

3. Disable automatic screen lock (or audio won't work until unlocked):
   ```bash
   gsettings set org.gnome.desktop.screensaver lock-enabled false
   gsettings set org.gnome.desktop.session idle-delay 0
   ```

4. Check status:
   ```bash
   grdctl status --show-credentials
   ```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Browser                               │
│                    (Guacamole Client)                        │
└─────────────────────────┬───────────────────────────────────┘
                          │ HTTP/WebSocket
┌─────────────────────────▼───────────────────────────────────┐
│                     guacamole                                │
│                  (Web Application)                           │
│                   Port 8085:8080                             │
└─────────────────────────┬───────────────────────────────────┘
                          │ Guacamole Protocol
┌─────────────────────────▼───────────────────────────────────┐
│                   janua-guacd                                │
│              (This Custom Build)                             │
│     FreeRDP 3.10.3 + RDPSND v8 Patch + PipeWire             │
│                   Port 4822                                  │
└─────────────────────────┬───────────────────────────────────┘
                          │ RDP Protocol
┌─────────────────────────▼───────────────────────────────────┐
│              GNOME Remote Desktop                            │
│                 (Wayland Target)                             │
│                   Port 3389                                  │
└─────────────────────────────────────────────────────────────┘
```

## Components

| Directory | Description |
|-----------|-------------|
| `guacd/` | Custom guacd Dockerfile with FreeRDP 3 and patches |
| `guacd/patches/` | RDPSND version 8 patch for GRD compatibility |
| `guacamole-branding/` | Browser AudioContext fix extension |
| `guacamole-home/` | Guacamole configuration (extensions, etc.) |
| `initdb/` | PostgreSQL initialization scripts |

## Building

Build just the guacd image:
```bash
docker build -t janua-guacd ./guacd
```

Build the branding extension (requires Maven):
```bash
cd guacamole-branding
mvn package
cp target/janua-branding-*.jar ../guacamole-home/extensions/
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `POSTGRES_PASSWORD` | `changeme` | PostgreSQL password |

### Docker Compose Services

- **guacd** - Custom guacd with FreeRDP 3 (network_mode: host)
- **guacamole** - Official Guacamole web app
- **postgres** - PostgreSQL database

### Volume Mounts

| Path | Description |
|------|-------------|
| `./drive` | Shared drive for file transfer |
| `./record` | Session recordings |
| `./postgres-data` | Database persistence |
| `./guacamole-home` | Guacamole extensions and config |

## Technical Details

### The RDPSND Patch

GNOME Remote Desktop requires RDPSND protocol version 8 (introduced in Windows 8.1). The official guacamole-server advertises version 6. This causes audio channel negotiation to fail silently.

The patch in `guacd/patches/rdpsnd-version-8.patch` changes:
```c
// Before
Stream_Write_UINT16(output_stream, 6);

// After
Stream_Write_UINT16(output_stream, 8);
```

### FreeRDP 3 Build Options

Key build flags enabled:
- `WITH_PIPEWIRE=ON` - PipeWire audio support
- `CHANNEL_RDPGFX=ON` - Graphics Pipeline Extension
- `CHANNEL_RDPSND=ON` - Audio redirection
- `WITH_PULSE=ON` - PulseAudio support
- `WITH_FFMPEG=ON` - Video codec support

## Troubleshooting

### "You have been disconnected" immediately
- Ensure screen is unlocked on target machine
- Check GRD is running: `systemctl --user status gnome-remote-desktop`

### No audio
- GNOME 48+ required for audio (Ubuntu 24.04's GRD 46 has a bug)
- Check that `enable-audio` is set in connection parameters
- Verify AudioContext is resumed (check browser console for `[Janua]` messages)

### Connection refused
- Verify RDP is enabled: `grdctl status`
- Check firewall allows port 3389
- Ensure TLS certificate is configured

## License

GNU 3.0 - See [LICENSE](LICENSE) for details.

## Credits

- [Apache Guacamole](https://guacamole.apache.org/) - The clientless remote desktop gateway
- [FreeRDP](https://www.freerdp.com/) - Free implementation of the Remote Desktop Protocol
- [GNOME Remote Desktop](https://gitlab.gnome.org/GNOME/gnome-remote-desktop) - Wayland-native RDP server

Copyright 2025 Skylark Software LLC
