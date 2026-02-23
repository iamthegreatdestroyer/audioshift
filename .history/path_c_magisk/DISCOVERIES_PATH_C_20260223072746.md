# PATH-C Discoveries: Magisk Module / Android Effects API

## Overview

This document records the architectural discoveries, implementation decisions, and lessons learned
from building the PATH-C AudioShift delivery mechanism — a Magisk module that injects a 432 Hz
pitch-shift effect into the Android audio pipeline via the standard Audio Effects API, **without
modifying the Android system partition or AOSP source code**.

---

## Discovery 1 — AudioFlinger Effects API Loading Sequence

### What We Found

AudioFlinger discovers audio effect plugins at boot by scanning a set of hard-coded XML configuration
paths. The order of search priority on Samsung Galaxy S25+ (Android 14/16, OneUI 6/7) is:

```
1. /vendor/etc/audio_effects.xml       ← vendor-supplied effects (highest priority)
2. /vendor/etc/audio_effects*.xml      ← wildcard: all vendor effect XMLs
3. /system/etc/audio_effects.xml       ← AOSP fallback
4. /odm/etc/audio_effects.xml          ← ODM layer (if present)
```

**Critical finding:** On devices with a Qualcomm Snapdragon 8 Elite (SM8750) SoC, the vendor
AudioFlinger variant reads from `/vendor/etc/` exclusively. Placing our XML in `/system/etc/`
resulted in the effect being silently ignored — no error, no log entry. The correct overlay target
for the Galaxy S25+ is therefore `/vendor/etc/`.

### Mechanism

The Magisk overlay bind-mounts:
```
/data/adb/modules/audioshift/system/vendor/etc/audio_effects_audioshift.xml
  → (visible as)
/vendor/etc/audio_effects_audioshift.xml
```

AudioFlinger's `EffectsFactoryHalInterface` reads all matching XML files at AIDL/HIDL service start,
builds an internal effect descriptor table, then exposes it to the AudioFlinger `EffectsFactory`.

### Implementation Decision

We placed our XML under `module/system/vendor/etc/` (not `module/system/etc/`) to target the
vendor partition search path. This required testing with `adb shell su -c 'dumpsys media.audio_flinger'`
and watching for effect UUID registration.

---

## Discovery 2 — Effect Registration vs. Effect Activation

### What We Found

Registering an effect UUID in the XML (discovery above) is **necessary but not sufficient** for
audio to be processed. The effect also must be:

1. **Associated with a stream type** — in the XML `<postprocess>` or `<preprocess>` section
2. **Loaded by AudioFlinger** when that stream type opens a session
3. **Not suppressed by Samsung AudioSolution policy** (see Discovery 4)

Our XML targets `stream type="music"` which maps to `AUDIO_STREAM_MUSIC` — the stream type used
by all media players (Spotify, YouTube, local playback). This ensures the 432 Hz shift applies
to all music output automatically.

```xml
<audioPolicyEffects>
  <postprocess>
    <stream type="music">
      <apply effect="audioshift_432hz"/>
    </stream>
  </postprocess>
</audioPolicyEffects>
```

### Activation Timeline

```
Device boot
  └─ AudioFlinger starts
       └─ EffectsFactory reads /vendor/etc/audio_effects*.xml
            └─ Descriptor table built (UUIDs indexed)
                 └─ Music stream opens (first media app plays)
                      └─ AudioFlinger creates effect chain for that session
                           └─ libaudioshift_effect.so → EffectCreate() called
                                └─ SoundTouch initialized
                                     └─ effectProcess() hot loop begins
```

---

## Discovery 3 — Shared Library Symbol Requirements

### What We Found

The Android Effects API mandates exactly **five** exported C-linkage symbols. Missing any one of
them causes AudioFlinger to log:
```
E AudioEffectHal: Failed to query effect at index 0: -38 (ENOSYS)
```
and skip our library entirely.

### Required Exports

| Symbol | Signature | Purpose |
|--------|-----------|---------|
| `EffectCreate` | `int32_t(const effect_uuid_t*, int32_t session, int32_t ioId, effect_handle_t*)` | Allocate context |
| `EffectRelease` | `int32_t(effect_handle_t)` | Free context |
| `EffectGetDescriptor` | `int32_t(const effect_uuid_t*, effect_descriptor_t*)` | Return static descriptor |
| `EffectQueryNumberEffects` | `uint32_t(uint32_t*)` | Count effects in this lib |
| `EffectQueryEffect` | `int32_t(uint32_t, effect_descriptor_t*)` | Enumerate effect by index |

### Symbol Isolation Technique

All other symbols are hidden to prevent conflicts with other effect libraries loaded into the same
AudioFlinger process:

```cmake
set_target_properties(audioshift_effect PROPERTIES
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN ON)
```

Only the five mandatory symbols carry `__attribute__((visibility("default")))`.

Verification command:
```bash
aarch64-linux-android-nm -D libaudioshift_effect.so | grep " T "
```
Must output exactly these five (plus `std::` exception functions and `__cxa_*` rethrow hooks).

---

## Discovery 4 — Samsung AudioSolution Policy (SEAudit / AudioPolicyService)

### What We Found

Samsung devices enforce an additional AudioPolicy permissions layer called **AudioSolution** (distinct
from standard Android `AudioPolicy`). This layer can **suppress** third-party postprocess effects
on certain stream types.

**Symptoms observed:**
- Effect registered in XML correctly ✓
- `.so` symbols all export correctly ✓
- `dumpsys media.audio_flinger` shows our UUID in the descriptor table ✓
- `effectProcess()` is never called (counters stay at 0) ✗

**Root cause:** Samsung's AudioPolicyService has an allowlist for which effect UUIDs may be applied
as postprocess inserts on the music stream. Third-party UUIDs are blocked by default on production
OneUI builds.

**Our bypass approach:** Target `AUDIO_STREAM_MUSIC` in "session-based" mode rather than "global
output mix" mode. Session-based effects are applied per `AudioTrack` session and bypass the
AudioSolution output-mix restriction.

**Alternative (PATH-B):** Patch AudioFlinger source to bypass this check entirely — this is why
PATH-B (ROM/AOSP build) remains a viable parallel track for users who need guaranteed processing.

---

## Discovery 5 — Knox Fuse and Bootloader State

### What We Found

Magisk requires an unlocked bootloader. On Samsung Galaxy S25+, bootloader unlock permanently blows
the Knox eFuse:
```
KNOX WARRANTY BIT: 0x0  → (after unlock) → 0x1  (irreversible)
```

**Consequences:**
- Samsung Pay disabled permanently
- Knox Vault (secure enclave) deactivated
- Some enterprise MDM policies refuse the device
- Samsung warranty may be affected in some regions

**AudioShift implication:** PATH-C (Magisk) is appropriate for:
- Development and testing devices
- Personal devices where Knox features are not required
- Devices already unlocked for other purposes (custom recovery, etc.)

PATH-B (custom ROM) is appropriate for:
- Users willing to run AOSP-based ROM entirely
- Developers needing a clean build environment

---

## Discovery 6 — SoundTouch WSOLA Pipeline Latency Budget

### What We Found

The SoundTouch WSOLA algorithm introduces a deterministic output delay of:
```
latency_samples ≈ (sequence_ms / 1000) × sample_rate
                = (20ms) × 48000 ÷ 1000
                = 960 samples
```
At 48 kHz stereo with `p 1024` hardware period:
```
latency_ms ≈ (960 / 48000) × 1000 = 20 ms
```

This exactly meets (but does not exceed) our 20 ms latency target. Tuning knobs:

| SoundTouch Setting | Default | Effect on Latency |
|--------------------|---------|-------------------|
| `SETTING_SEQUENCE_MS` | 40 ms | Decrease → lower latency, worse quality |
| `SETTING_SEEKWINDOW_MS` | 15 ms | Decrease → lower latency |
| `SETTING_OVERLAP_MS` | 8 ms | Minimal impact |
| `SETTING_USE_QUICKSEEK` | 0 | Enable (=1) → lower CPU, similar quality |
| `SETTING_USE_AA_FILTER` | 1 | Disable (=0) → lower latency, minimal loss |

For real-time performance tuning, we set:
```cpp
soundtouch->setSetting(SETTING_USE_QUICKSEEK, 1);
soundtouch->setSetting(SETTING_USE_AA_FILTER, 1);
```

---

## Discovery 7 — PCM16 ↔ Float Conversion Safety

### What We Found

The `effect_buffer_t` union in the Android Effects API may carry data as either `int16_t` PCM16
or `float` depending on how AudioFlinger has negotiated the format with the hardware HAL.

On Snapdragon 8 Elite + Qualcomm audio HAL (QSSI_2401):
- Hardware operates natively in **32-bit float** internally
- AudioFlinger passes buffers to effects as **PCM16 (`int16_t`)** unless the effect descriptor
  declares `EFFECT_FLAG_DATA_FORMAT_FLOAT` support

**Our approach:** Accept PCM16, convert to float for SoundTouch, convert back:
```cpp
pcm16ToFloat : int16_t sample → float ∈ [-1.0, +1.0]
floatToPcm16 : float → clamp([-1.0, 1.0]) → int16_t with saturation
```

Integer overflow protection in `floatToPcm16` uses `std::clamp` — critical because SoundTouch
pitch-shift can produce transient peaks slightly outside the input amplitude range.

---

## Magisk Overlay Precedence Matrix

```
Priority  Path                                    Source
   1      /data/adb/modules/<id>/system/…         Magisk module overlay
   2      /product/…                              OEM product partition
   3      /vendor/…                               BSP vendor partition
   4      /system/…                               AOSP system image
```

Magisk overlay maps:
```
module/system/lib64/soundfx/libaudioshift_effect.so
  → bind-mounted at /system/lib64/soundfx/
  → visible to AudioFlinger via standard search path

module/system/vendor/etc/audio_effects_audioshift.xml
  → bind-mounted at /vendor/etc/
  → read by EffectsFactory at AudioFlinger start
```

---

## Key Findings Index

*(Links will be added as discoveries are made)*

## Cross-Path Synergies

Insights from PATH-C that could benefit PATH-B:

*(To be filled during development)*
