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
| KDE Plasma KRdp | ✅ | ✅ | Requires H.264/AVC support |
| GNOME Remote Desktop (GNOME 48+) | ✅ | ✅ | Fedora 42, Ubuntu 25.04+ |
| GNOME Remote Desktop (GNOME 46) | ✅ | ❌ | Ubuntu 24.04 - GRD has PipeWire threading bug |
| xrdp | ✅ | ✅ | Full compatibility |
| Windows RDP | ✅ | ✅ | Full compatibility |

**Note:** Ubuntu 24.04's GNOME Remote Desktop (GRD 46.3) has a [known PipeWire threading issue](https://gitlab.gnome.org/GNOME/gnome-remote-desktop/-/issues/182) that prevents audio capture. This is fixed in GNOME 48 (Fedora 42, Ubuntu 25.04+).

## Quick Start

For a comprehensive guide including prerequisites, see the [Full Setup Guide](docs/SETUP.md).

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
│                        Browser                              │
│                    (Guacamole Client)                       │
└─────────────────────────┬───────────────────────────────────┘
                          │ HTTP/WebSocket
┌─────────────────────────▼───────────────────────────────────┐
│                     guacamole                               │
│                  (Web Application)                          │
│                   Port 8085:8080                            │
└─────────────────────────┬───────────────────────────────────┘
                          │ Guacamole Protocol
┌─────────────────────────▼───────────────────────────────────┐
│                   janua-guacd                               │
│              (This Custom Build)                            │
│     FreeRDP 3.10.3 + RDPSND v8 Patch + PipeWire             │
│                   Port 4822                                 │
└─────────────────────────┬───────────────────────────────────┘
                          │ RDP Protocol
┌─────────────────────────▼───────────────────────────────────┐
│              GNOME Remote Desktop                           │
│                 (Wayland Target)                            │
│                   Port 3389                                 │
└─────────────────────────────────────────────────────────────┘
```

## Components

| Directory | Description |
|-----------|-------------|
| `guacd/` | Custom guacd Dockerfile with FreeRDP 3 and patches |
| `guacd/patches/` | Patches for RDPGFX, H.264, and audio support (see Technical Details) |
| `guacamole-branding/` | Browser AudioContext fix extension |
| `guacamole-home/` | Guacamole configuration (extensions, etc.) |
| `initdb/` | PostgreSQL initialization scripts |

## Building

Build just the guacd image:
```bash
docker build -t janua-guacd ./guacd
```

### Using Pre-built Image (Optional)

If you prefer to skip the build, you can use the pre-built image from GitHub Container Registry. Edit `docker-compose.yml` and replace the guacd service:
```yaml
services:
  guacd:
    image: ghcr.io/skylark-software/janua-guacd:latest
```

### Building the Branding Extension

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

### Patches

Janua applies three patches to guacamole-server for full RDPGFX/H.264 and audio support:

#### 1. RDPSND Version 8 (`rdpsnd-version-8.patch`)

GNOME Remote Desktop requires RDPSND protocol version 8 (introduced in Windows 8.1). The official guacamole-server advertises version 6, causing audio channel negotiation to fail silently.

```c
// Before
Stream_Write_UINT16(output_stream, 6);

// After
Stream_Write_UINT16(output_stream, 8);
```

#### 2. H.264/AVC Support (`h264-avc-support.patch`)

KDE KRdp and modern GNOME Remote Desktop require H.264 codec support via RDPGFX. This patch enables the AVC420 codec in FreeRDP settings:

```c
freerdp_settings_set_bool(rdp_settings, FreeRDP_GfxH264, TRUE);
freerdp_settings_set_bool(rdp_settings, FreeRDP_GfxProgressive, TRUE);
```

Note: Only AVC420 is enabled. KDE KRdp specifically requires YUV420 mode and rejects connections with AVC444.

#### 3. RDPGFX Surface Sync (`gdi-rdpgfx-sync.patch`)

When using H.264, decoded frames are written to separate RDPGFX surface buffers. Without synchronization, the display appears scrambled. This patch calls `UpdateSurfaces()` via the graphics pipeline context to copy decoded H.264 frames to the primary buffer before rendering:

```c
if (gdi->gfx) {
    RdpgfxClientContext* gfx = (RdpgfxClientContext*) gdi->gfx;
    if (gfx->UpdateSurfaces)
        gfx->UpdateSurfaces(gfx);
}
```

### FreeRDP 3 Build Options

Key build flags enabled:
- `WITH_OPENH264=ON` - H.264 codec support (required for KDE KRdp)
- `WITH_VIDEO_FFMPEG=ON` - FFmpeg video codec support
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

### Scrambled or distorted display (KDE KRdp)
- Non-standard resolutions may cause display synchronization issues with H.264 decoding
- Try using a standard resolution (1920x1080, 2560x1440, etc.)
- This is related to stride alignment in the RDPGFX pipeline

## License

GNU 3.0 - See [LICENSE](LICENSE) for details.

## Credits

- [Apache Guacamole](https://guacamole.apache.org/) - The clientless remote desktop gateway
- [FreeRDP](https://www.freerdp.com/) - Free implementation of the Remote Desktop Protocol
- [GNOME Remote Desktop](https://gitlab.gnome.org/GNOME/gnome-remote-desktop) - Wayland-native RDP server

Copyright 2025 Skylark Software LLC
