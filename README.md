# Janua

A custom Apache Guacamole guacd build with FreeRDP 3 support, enabling compatibility with modern Wayland-based remote desktop servers including GNOME Remote Desktop.

## Why Janua?

The official Apache Guacamole guacd Docker image uses FreeRDP 2.x, which lacks support for the Graphics Pipeline Extension (GFX) required by GNOME Remote Desktop and other modern RDP servers. Janua bridges this gap by building guacd against FreeRDP 3.x.

**Janua** - Latin for "door" or "gateway"

## Features

- FreeRDP 3.x support with full GFX Pipeline Extension
- Compatible with GNOME Remote Desktop (Wayland)
- Compatible with xrdp (X11)
- Drop-in replacement for official guacd image
- Audio redirection support

## Quick Start

```bash
docker-compose up -d
```

Access Guacamole at `http://localhost:8080/guacamole`

Default credentials: `guacadmin` / `guacadmin`

## Building

```bash
docker build -t janua-guacd ./guacd
```

## Configuration

See `docker-compose.yml` for full stack deployment including:
- guacd (this custom build)
- guacamole (web frontend)
- PostgreSQL (database)

## License

Apache License 2.0 - See [LICENSE](LICENSE) for details.

## Credits

- [Apache Guacamole](https://guacamole.apache.org/) - The clientless remote desktop gateway
- [FreeRDP](https://www.freerdp.com/) - Free implementation of the Remote Desktop Protocol
- Built with [Claude Code](https://claude.ai/claude-code)

Copyright 2025 Skylark Software LLC
