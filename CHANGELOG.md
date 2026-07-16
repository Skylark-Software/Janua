# Changelog

All notable changes to Janua are documented here. This project follows
[Semantic Versioning](https://semver.org/). The stable line lives on `main`;
the beta line lives on the `1.2-beta` branch.

## [1.2.0-beta.2] - 2026-07-16

### Changed
- Rebased the guacd image on **Debian 13 (trixie)**, moving the runtime to
  FFmpeg 7 and current system libraries. No functional change to the beta stack
  (FreeRDP 3.29.0 + experimental AV1) — a base/security refresh only.

## [1.0.1] - 2026-07-16

### Changed
- Rebased the guacd image on **Debian 13 (trixie)** (from Debian 12), moving the
  runtime to FFmpeg 7 and current system libraries. No functional change to Janua
  itself — same FreeRDP 3.10.3 client stack, patches, and features.

### Fixed
- Corrected the hunk-count header in `guacd/patches/gdi-rdpgfx-sync.patch` so the
  stricter `patch(1)` on Debian 13 accepts it (the previous header only applied
  cleanly under Debian 12's more lenient patch).

### Added
- Monthly scheduled workflow (`.github/workflows/scheduled-rebuild.yml`) that
  rebuilds and republishes the guacd images on the first of each month, so the
  Debian base picks up security updates even without code changes.

## [1.2.0-beta.1] - 2026-07-15

### Added
- Beta line: guacd rebuilt on **FreeRDP 3.29.0** (from 3.10.3) — ~2 years of
  upstream fixes including 50+ CVE patches — plus experimental AV1 support for
  the graphics pipeline (`WITH_GFX_AV1`, libaom). Prebuilt image published to
  `ghcr.io/skylark-software/janua:beta`.
- `CHANNEL=beta` option in the Proxmox VE LXC installer to target this line.

## [1.0.0] - 2026-07-15

### Added
- First stable release. Apache Guacamole 1.6.0 fork with guacd built on
  FreeRDP 3.10.3: H.264/AVC for KDE KRdp and GNOME Remote Desktop, RDPSND v8,
  a GDI/RDPGFX surface-sync fix, Janua branding, a Proxmox VE LXC installer,
  and TOTP two-factor support via `TOTP_ENABLED` / `TOTP_ISSUER`.
