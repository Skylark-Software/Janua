# Janua H.264/AVC Support Implementation Plan

## Overview

This document outlines the development plan to add H.264/AVC codec support to Janua's guacd, enabling compatibility with RDP servers that require H.264 (like KDE's KRdp and modern GNOME Remote Desktop).

**Estimated Effort:** 15-24 person-days
**Complexity:** Medium-High
**Target:** Janua guacd 2.0

---

## Problem Statement

Modern Wayland RDP servers (KRdp, GRD) require the RDPGFX Graphics Pipeline Extension with H.264 codec support. Current Guacamole/Janua guacd does not advertise H.264 capability, causing these connections to fail with:

```
Client does not support H.264 in YUV420 mode!
ERRINFO_GRAPHICS_SUBSYSTEM_FAILED
```

---

## Technical Background

### Current Architecture

```
Browser ←→ guacamole-client ←→ guacd ←→ FreeRDP ←→ RDP Server
                                 ↓
                          PNG/JPEG/WebP
                          (no H.264)
```

### Target Architecture

```
Browser ←→ guacamole-client ←→ guacd ←→ FreeRDP ←→ RDP Server
                                 ↓
                          H.264 decode
                               ↓
                          YUV→RGB convert
                               ↓
                          PNG/JPEG/WebP
```

### RDPGFX Capability Negotiation

1. Client sends `RDPGFX_CAPS_ADVERTISE_PDU` with supported codecs
2. Server responds with `RDPGFX_CAPS_CONFIRM_PDU` selecting a codec
3. All subsequent graphics use the negotiated codec

**H.264 Capability Flags:**
- `RDPGFX_CAPS_FLAG_AVC420_ENABLED` - YUV 4:2:0 (standard)
- `RDPGFX_CAPS_FLAG_AVC444_ENABLED` - YUV 4:4:4 (better for text)

**H.264 Codec IDs:**
- `RDPGFX_CODECID_AVC420 (0x000B)`
- `RDPGFX_CODECID_AVC444 (0x000E)`
- `RDPGFX_CODECID_AVC444v2 (0x000F)`

---

## Implementation Phases

### Phase 1: Configuration Foundation (1-2 days)

**Objective:** Add H.264 configuration options to Janua/Guacamole

**Files to Modify:**
- `src/protocols/rdp/settings.h`
- `src/protocols/rdp/settings.c`

**Changes:**

1. Add settings structure fields:
```c
// In guac_rdp_settings struct
bool enable_gfx_h264;      // Master H.264 enable
bool enable_gfx_avc420;    // AVC420 (YUV 4:2:0)
bool enable_gfx_avc444;    // AVC444 (YUV 4:4:4)
```

2. Parse connection parameters:
```c
// New connection parameters
"enable-gfx-h264"   // Default: true
"enable-gfx-avc420" // Default: true
"enable-gfx-avc444" // Default: false (more CPU)
```

3. Wire to FreeRDP settings:
```c
freerdp_settings_set_bool(rdp_settings, FreeRDP_GfxH264, settings->enable_gfx_h264);
freerdp_settings_set_bool(rdp_settings, FreeRDP_GfxAVC420, settings->enable_gfx_avc420);
freerdp_settings_set_bool(rdp_settings, FreeRDP_GfxAVC444, settings->enable_gfx_avc444);
```

**Deliverables:**
- [ ] Settings structure updated
- [ ] Parameter parsing implemented
- [ ] FreeRDP settings wired

---

### Phase 2: H.264 Codec Initialization (3-5 days)

**Objective:** Initialize H.264 decoder context in FreeRDP

**Files to Modify:**
- `src/protocols/rdp/rdp.c`
- `src/protocols/rdp/channels/rdpgfx.c`

**Changes:**

1. Verify H.264 subsystem availability:
```c
// During connection setup
H264_CONTEXT* h264 = h264_context_new(FALSE);
if (h264 && h264_context_init(h264)) {
    // H.264 available - enable in settings
    guac_client_log(client, GUAC_LOG_INFO,
        "H.264 decoder available: %s", h264->subsystem->name);
} else {
    guac_client_log(client, GUAC_LOG_WARNING,
        "H.264 decoder not available - falling back to RemoteFX");
}
```

2. Initialize codec in RDPGFX channel connected callback:
```c
// In guac_rdp_rdpgfx_channel_connected()
rdpGdi* gdi = rdp_context->gdi;
if (settings->enable_gfx_h264) {
    if (!gdi->codecs->h264) {
        gdi->codecs->h264 = h264_context_new(FALSE);
        h264_context_init(gdi->codecs->h264);
    }
}
```

3. Add H.264 libraries to Dockerfile:
```dockerfile
# Build dependencies
libx264-dev \
libopenh264-dev \

# Runtime dependencies
libx264-164 \
libopenh264-7 \
```

**Deliverables:**
- [ ] H.264 context initialization
- [ ] Subsystem detection and logging
- [ ] Dockerfile updated with H.264 libs
- [ ] Fallback when H.264 unavailable

---

### Phase 3: Capability Advertisement (3-5 days)

**Objective:** Advertise H.264 support in RDPGFX capability exchange

**Files to Modify:**
- `src/protocols/rdp/channels/rdpgfx.c`

**Key Understanding:**

FreeRDP's RDPGFX client plugin handles capability negotiation automatically when:
1. `GfxH264` setting is TRUE
2. H.264 codec context is initialized
3. Capability version 8.1+ is used

**Changes:**

1. Verify FreeRDP advertises H.264:
```c
// Add logging in capability callback
static UINT guac_rdpgfx_caps_confirm(RdpgfxClientContext* context,
    const RDPGFX_CAPS_CONFIRM_PDU* capsConfirm) {

    guac_client_log(client, GUAC_LOG_INFO,
        "RDPGFX capabilities confirmed: version=0x%08X flags=0x%08X",
        capsConfirm->capsSet->version, capsConfirm->capsSet->flags);

    if (capsConfirm->capsSet->flags & RDPGFX_CAPS_FLAG_AVC420_ENABLED)
        guac_client_log(client, GUAC_LOG_INFO, "H.264 AVC420 enabled");
    if (capsConfirm->capsSet->flags & RDPGFX_CAPS_FLAG_AVC444_ENABLED)
        guac_client_log(client, GUAC_LOG_INFO, "H.264 AVC444 enabled");

    return CHANNEL_RC_OK;
}
```

2. If FreeRDP doesn't advertise H.264, patch capability building:
```c
// May need to intercept CAPS_ADVERTISE and add flags
capsSet->flags |= RDPGFX_CAPS_FLAG_AVC420_ENABLED;
if (settings->enable_gfx_avc444)
    capsSet->flags |= RDPGFX_CAPS_FLAG_AVC444_ENABLED;
```

**Deliverables:**
- [ ] Capability logging added
- [ ] Verify H.264 advertised in CAPS_ADVERTISE
- [ ] Handle CAPS_CONFIRM response
- [ ] Patch capability building if needed

---

### Phase 4: Surface Frame Decoding (3-5 days)

**Objective:** Route H.264 frames through decoder pipeline

**Files to Modify:**
- `src/protocols/rdp/channels/rdpgfx.c`
- `src/protocols/rdp/gdi.c` (if exists)

**Key Understanding:**

FreeRDP's GDI graphics pipeline (`gdi_graphics_pipeline_init()`) already handles H.264 decoding via callbacks:
- `SurfaceCommand` callback receives codec ID
- Routes to `rdpgfx_decode_AVC420()` or `rdpgfx_decode_AVC444()`
- Decodes H.264 → YUV → RGB automatically

**Changes:**

1. Ensure GDI pipeline is properly initialized:
```c
// In guac_rdp_rdpgfx_channel_connected()
if (!gdi_graphics_pipeline_init(gdi, rdpgfx)) {
    guac_client_log(client, GUAC_LOG_ERROR,
        "Failed to initialize GDI graphics pipeline");
    return FALSE;
}
```

2. Verify surface updates flow to Guacamole display:
```c
// The existing BeginPaint/EndPaint callbacks should work
// H.264 frames decode to GDI surface
// Guacamole reads from GDI surface
```

3. Handle potential YUV conversion issues:
```c
// If needed, add explicit YUV→RGB conversion
if (codecId == RDPGFX_CODECID_AVC420 || codecId == RDPGFX_CODECID_AVC444) {
    // FreeRDP handles this in rdpgfx_decode_AVC*
    // Just verify output format matches Guacamole expectations
}
```

**Deliverables:**
- [ ] GDI pipeline initialization verified
- [ ] H.264 frame decoding working
- [ ] YUV→RGB conversion verified
- [ ] Surface updates flowing to Guacamole

---

### Phase 5: Testing & Debugging (5-7 days)

**Objective:** Validate H.264 with various RDP servers

**Test Matrix:**

| Server | H.264 Mode | Expected Result |
|--------|------------|-----------------|
| KDE KRdp | AVC420 | Video + Audio |
| GNOME GRD (F42) | AVC420 | Video + Audio |
| Windows 10/11 | AVC420/444 | Video + Audio |
| Windows Server | AVC420/444 | Video + Audio |
| xrdp (fallback) | None | RemoteFX/bitmap |

**Test Cases:**

1. **Basic connectivity:**
   - [ ] Connect to KRdp
   - [ ] Connect to GRD
   - [ ] Connect to Windows

2. **Codec negotiation:**
   - [ ] Verify CAPS_ADVERTISE includes H.264 flags
   - [ ] Verify CAPS_CONFIRM selects H.264
   - [ ] Log codec ID in surface commands

3. **Video quality:**
   - [ ] Smooth desktop rendering
   - [ ] Video playback (YouTube, VLC)
   - [ ] Text readability (AVC444 if available)

4. **Fallback:**
   - [ ] Connect to non-H.264 server (xrdp)
   - [ ] Verify graceful fallback to RemoteFX

5. **Performance:**
   - [ ] CPU usage acceptable
   - [ ] Latency reasonable
   - [ ] Memory usage stable

**Deliverables:**
- [ ] All test cases passing
- [ ] Performance benchmarks documented
- [ ] Edge cases handled

---

## File Summary

| File | Changes |
|------|---------|
| `guacd/Dockerfile` | Add libx264, libopenh264 |
| `src/protocols/rdp/settings.h` | Add H.264 settings fields |
| `src/protocols/rdp/settings.c` | Parse H.264 parameters |
| `src/protocols/rdp/rdp.c` | Wire FreeRDP H.264 settings |
| `src/protocols/rdp/channels/rdpgfx.c` | H.264 init, caps, decoding |

---

## Dependencies

### Build Dependencies
```
libx264-dev
libopenh264-dev
libavcodec-dev (already included)
```

### Runtime Dependencies
```
libx264-164 (or newer)
libopenh264-7 (or newer)
libavcodec59 (already included)
```

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| FreeRDP API changes | Low | High | Pin to FreeRDP 3.10.x |
| H.264 patent issues | Low | Medium | Use OpenH264 (Cisco licensed) |
| Performance issues | Medium | Medium | Allow AVC420/444 toggle |
| Browser compatibility | Low | Low | No change to browser side |

---

## Success Criteria

1. **KRdp works:** Connect to KDE Plasma KRdp with video
2. **GRD works:** Connect to GNOME Remote Desktop with video + audio
3. **Fallback works:** Graceful fallback on non-H.264 servers
4. **No regressions:** Existing connections still work

---

## References

- [FreeRDP RDPGFX Implementation](https://github.com/FreeRDP/FreeRDP/tree/master/channels/rdpgfx)
- [FreeRDP H.264 Codec](https://github.com/FreeRDP/FreeRDP/blob/master/libfreerdp/codec/h264.c)
- [MS-RDPEGFX Specification](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-rdpegfx/)
- [Guacamole RDP Protocol](https://github.com/apache/guacamole-server/tree/main/src/protocols/rdp)
- [KRDP and Apache Guacamole Discussion](https://discuss.kde.org/t/krdp-and-apache-guacamole-rdp/38026)

---

## Appendix: FreeRDP H.264 Settings

```c
// Relevant FreeRDP settings
FreeRDP_GfxH264          // Master H.264 enable
FreeRDP_GfxAVC420        // AVC420 codec enable
FreeRDP_GfxAVC444        // AVC444 codec enable
FreeRDP_GfxAVC444v2      // AVC444v2 codec enable
FreeRDP_GfxSmallCache    // Small cache mode
FreeRDP_GfxThinClient    // Thin client mode
```

---

*Document Version: 1.0*
*Created: 2025-12-12*
*Author: Janua Development Team*
