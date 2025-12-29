# Third-Party Notices

This directory contains license and attribution notices for third-party
components used in Janua.

## Components

| Component | License | Notice File |
|-----------|---------|-------------|
| Apache Guacamole | Apache 2.0 | `apache-guacamole.txt` |
| FreeRDP | Apache 2.0 | `freerdp.txt` |

## Apache 2.0 Compliance

Per Apache License 2.0, Section 4, derivative works must:

- Include a copy of the Apache 2.0 license (see `LICENSES/Apache-2.0.txt`)
- State changes made to modified files
- Retain copyright and attribution notices

## Modifications

Janua applies patches to Apache Guacamole guacamole-server to add:

1. FreeRDP 3 support
2. H.264/AVC codec support for RDPGFX
3. RDPSND protocol version 8 for modern RDP servers
4. GDI/RDPGFX surface synchronization fix

See `apache-guacamole.txt` for specific file modifications.
