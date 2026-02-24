# AudioShift

> **System-wide 432 Hz pitch-shifting for Android**
> Magisk module & Custom ROM — no app modifications required.

---

## What Is AudioShift?

AudioShift intercepts all audio output on a rooted Android device and passes it through a
real-time DSP pipeline that lowers the pitch by −31.77 cents —
the exact interval from the ISO 440 Hz standard to the historical 432 Hz tuning.

Every sound on the device is affected: music, video, system sounds, notifications.
No individual app needs to be modified or replaced.

### The Math

$$
\text{ratio} = \frac{432}{440} \approx 0.98182
$$

$$
\Delta \text{semitones} = 12 \log_2\!\left(\frac{432}{440}\right) \approx -0.3164 \text{ st}
$$

$$
\Delta \text{cents} = 1200 \log_2\!\left(\frac{432}{440}\right) \approx -31.77 \text{ cents}
$$

AudioShift uses **−52 cents** (SoundTouch integer API nearest value) as the implementation
setpoint — see [Architecture](ARCHITECTURE.md) §3 for the four-point rationale.

---

## Implementation Paths

| Path                      | Approach                                               | Root Required | Flash Required | Status   |
| ------------------------- | ------------------------------------------------------ | :-----------: | :------------: | -------- |
| **PATH-C: Magisk Module** | Inject via Magisk, patch `libaudioclient.so`           |    ✅ Yes     |     ❌ No      | Primary  |
| **PATH-B: Custom ROM**    | AOSP build-system integration, `AudioEffect.cpp` patch |    ✅ Yes     |     ✅ Yes     | Research |

---

## Quick Navigation

<div class="grid cards" markdown>

- :material-rocket-launch: **[Getting Started](GETTING_STARTED.md)**

  ***

  Install AudioShift on a rooted device in under 10 minutes.

- :material-floor-plan: **[Architecture](ARCHITECTURE.md)**

  ***

  DSP pipeline design, SoundTouch integration, hook strategy.

- :material-api: **[API Reference](API_REFERENCE.md)**

  ***

  C++ DSP library reference — audio_432hz, audio_pipeline.

- :material-devices: **[Device Support](DEVICE_SUPPORT.md)**

  ***

  Tested hardware matrix, known limitations, compatibility notes.

- :material-wrench: **[Troubleshooting](TROUBLESHOOTING.md)**

  ***

  Common problems, log collection, debug builds.

- :material-account-group: **[Development Guide](DEVELOPMENT_GUIDE.md)**

  ***

  Build from source, run tests, submit contributions.

</div>

---

## Requirements

| Requirement     | Minimum                                                |
| --------------- | ------------------------------------------------------ |
| Android version | 12 (API 31)                                            |
| Root solution   | Magisk v26+ (PATH-C) or AOSP build (PATH-B)            |
| Architecture    | `arm64-v8a`                                            |
| Tested device   | Samsung Galaxy S25+ (SM-S926B) — Android 15 / One UI 7 |

---

## Project Status

AudioShift is under active development. Current tracking:

| Track   | Deliverable                                    | Status      |
| ------- | ---------------------------------------------- | ----------- |
| Track 0 | CI infrastructure, living docs                 | ✅ Complete |
| Track 1 | PATH-C Magisk validation scripts               | ✅ Complete |
| Track 2 | PATH-B Custom ROM skeleton (AOSP)              | ✅ Complete |
| Track 3 | CI expansion: 8-job pipeline, research scripts | ✅ Complete |
| Track 4 | Documentation & Community (this site)          | ✅ Complete |

---

!!! tip "New to AudioShift?"
Start with [Getting Started](GETTING_STARTED.md) to install the Magisk module on your device.

!!! info "Developer?"
See the [Development Guide](DEVELOPMENT_GUIDE.md) to build from source and run the test suite.
