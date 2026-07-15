# Issue #7 Investigation Notes

## Issue Summary
GitHub Issue: https://github.com/Skylark-Software/Janua/issues/7
Reporter: alexandruiancu (Alex Iancu)
Date: 2026-05-23

## Problem: KDE krdpserver connection fails with Janua guacd

### Setup
Reporter swapped `docker.io/guacamole/guacd:latest` for `ghcr.io/skylark-software/janua:latest`
in an existing guacamole pod (kept upstream `guacamole/guacamole:latest` web frontend).
Target: KDE desktop on Fedora (latest), krdpserver on port 3389.

### Symptoms
- krdpserver logs: `Connection reset by peer`, `Broken pipe` during RDP negotiation
- krdpserver built with `WITH_GFX_AV1=ON` (experimental, FreeRDP >= 3.25.0)
- `rdpMcs::userId == 0, skip sending PDU_TYPE_DEACTIVATE_ALL` — peer disconnects before activation

### Reporter's Self-Diagnosis (comment 2026-05-23)
Root cause was **missing libx264 codec on the host** — Fedora ships free-only ffmpeg by default;
krdpserver needs rpmfusion nonfree ffmpeg for H.264 encode support. After swapping to nonfree
ffmpeg, the original broken-pipe error resolved but a new issue appeared: `DRM device not found`.

## Analysis

### Is there a guacd ↔ guacamole-web protocol conflict?
**No.** Janua guacd and upstream guacamole-web both speak Guacamole protocol 1.6.0 over TCP 4822.
The web frontend is agnostic to which guacd backs it. Mixing them is a supported configuration.

### AV1 codec investigation
- `WITH_GFX_AV1` is a FreeRDP-proprietary extension (not MS-RDPEGFX spec), landed in FreeRDP 3.25.0
- Janua guacd builds FreeRDP 3.10.3 — the AV1 cmake flag doesn't exist in that version
- RDPGFX capability negotiation falls back gracefully: if guacd doesn't advertise
  `RDPGFX_CAPVERSION_FRDP_1`, the server skips AV1 and negotiates H.264/AVC or lower
- AV1 requires libaom (not dav1d); still marked `[experimental,unstable ABI/API]` upstream
- **Verdict: AV1 is a red herring for this issue.** The broken pipe was caused by the host
  missing libx264, not by a codec negotiation failure between guacd and krdpserver

### The actual root cause chain
1. Fedora ships ffmpeg without libx264 (patent/license reasons — needs rpmfusion nonfree)
2. krdpserver links against system FreeRDP, which links against system ffmpeg
3. Without libx264, krdpserver cannot encode H.264 frames for the GFX pipeline
4. RDP connection fails during capability activation → broken pipe
5. This is a **host configuration issue**, not a Janua bug

### DRM device not found (follow-up)
After fixing libx264, reporter now sees `DRM device not found`. This is krdpserver needing
access to `/dev/dri/*` for GPU-accelerated screen capture. Common causes:
- Running in a headless/VM environment without GPU passthrough
- Missing `render` group membership for the user running krdpserver
- Wayland compositor not exposing DRM to krdpserver

## FreeRDP Version Bump Assessment

### Current: 3.10.3 | Latest: 3.26.0 (2026-05-06)

### What a bump would gain
- **50+ CVE fixes** across 3.20.1–3.26.0 (input validation, codec bounds checks, channel handling)
  — staying on 3.10.3 is a security liability for internet-facing deployments
- AV1 GFX support (experimental, from 3.25.0) — requires libaom-dev, marginal value today
- AVC444 decode alignment fix (3.18) — could fix edge-case frame rendering
- RDPSND AAC encoder lag fix (3.18), thread cleanup race fix (3.22)
- Better compatibility with newer krdpserver/GNOME Remote Desktop versions
- ~18 months of bug fixes and protocol improvements

### What a bump risks
- **Deprecated API removals in progress.** guacd uses `freerdp_abort_connect()` and certificate
  callbacks that are deprecated (replaced by `_context()` variants). Default build still includes
  them, but FreeRDP 3.23+ urges consumers to test without — removal expected in a near-future minor.
- `WINPR_ATTR_NODISCARD` added to GDI/settings functions (3.22+) — generates compiler warnings
  for unchecked return values (guacd will trigger these)
- Our three patches target guacamole-server, not FreeRDP, so they should apply regardless.
  However, behavioral changes in GFX pipeline (bounds check fixes in 3.26) need regression testing.
- Build against FFmpeg 8.0+: `AV_PROFILE_AAC_MAIN` constant removed (3.19 addressed this)
- Full regression testing needed: Windows, GNOME GRD, KDE krdpserver, xrdp

### API migration checklist (if bumping)
- [ ] `freerdp_abort_connect()` → `freerdp_abort_connect_context()`
- [ ] `freerdp_shall_disconnect()` → `freerdp_shall_disconnect_context()`
- [ ] `freerdp_disconnect_before_reconnect()` → context variant
- [ ] Verify `pVerifyCertificateEx` / `pVerifyX509Certificate` callback usage
- [ ] Suppress or fix `WINPR_ATTR_NODISCARD` warnings
- [ ] Test with `WITHOUT_FREERDP_3x_DEPRECATED=ON` to future-proof

### Recommendation
**Bump is justified primarily for security (CVEs), not for this issue.** The reporter's problem
is host-side (missing libx264). However, the 50+ CVE gap makes upgrading a priority for any
deployment exposed to untrusted RDP targets. Track as a separate enhancement:
1. Fork guacd Dockerfile to a `freerdp-bump` branch
2. Test patches against 3.26.0
3. Audit guacamole-server for deprecated FreeRDP API calls
4. Regression test against Windows, GNOME GRD, krdpserver, xrdp
5. Optionally enable AV1 behind a build flag (experimental)

## Action Items

- [ ] Respond to issue #7 confirming the diagnosis and providing DRM guidance
- [ ] Consider adding a troubleshooting section to README for Fedora/krdpserver (libx264, DRM)
- [ ] Evaluate FreeRDP bump to 3.26.0 as separate work (test patch compatibility)
- [ ] Decide whether to publish `janua-guacd:latest` as the ghcr tag (current `janua:latest` is ambiguous)

## Reproduction Test (2026-05-24)

### Environment
- **guacd**: meadowlark, janua-guacd:latest (FreeRDP 3.10.3, Guacamole 1.6.0)
- **krdpserver**: aurora, krdp 6.6.4 linked against FreeRDP 3.26.0 (Fedora 44 KDE)
- **aurora codec stack**: rpmfusion nonfree ffmpeg 8.0.2, libx264, libopenh264, libaom 3.13.3

### Procedure
1. Started krdpserver on aurora port 3390 (`krdpserver --port 3390 --plasma`, avoiding xrdp on 3389)
2. Sent raw Guacamole protocol handshake to meadowlark guacd (TCP 4822) targeting aurora:3390
3. guacd returned `ready` — RDP session established successfully

### guacd logs
```
Creating new client for protocol "rdp"
Connection ID is "$0b72992b-a7b9-4eb5-b0c3-2bd1877c4c58"
Security mode: Negotiate (ANY)
Connection "$0b72992b-a7b9-4eb5-b0c3-2bd1877c4c58" removed.
```

### Result
**Cannot reproduce.** Janua guacd (FreeRDP 3.10.3) connects cleanly to krdpserver (FreeRDP 3.26.0
with AV1 support). No broken pipe, no codec negotiation failure. Confirms reporter's self-diagnosis:
the root cause was missing libx264 on the host, not a Janua/guacd issue.

### Key difference from reporter's setup
Aurora has rpmfusion nonfree ffmpeg with libx264 installed. The reporter's Fedora had only the
free ffmpeg (no libx264). Without H.264 encode capability, krdpserver can't produce GFX frames,
causing the connection to fail during activation.

## Test Environment
- **Dev host**: meadowlark (pushy-meadowlark)
- **Janua repo**: /home/jbrame/Janua-github/ (meadowlark), ~/development/projects/gitprojects/Janua (aurora)
- **Running containers**: janua-guacd (host network), janua-web (:8085), janua-postgres
