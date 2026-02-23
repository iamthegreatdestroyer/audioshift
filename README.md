# AudioShift — Real-time 432 Hz Audio Conversion for Android

**Dual-path implementation of system-level audio pitch-shift to 432 Hz tuning on Android**

## Overview

AudioShift is an innovative exploration of Android audio architecture through parallel development of two complementary implementations:

- **PATH-B:** Custom Android ROM with kernel-level audio pipeline modification
- **PATH-C:** Magisk module for runtime audio interception on stock Android

Both paths deliver real-time 432 Hz conversion with different tradeoffs between coverage, latency, and compatibility.

## Why AudioShift?

### The Innovation Philosophy

AudioShift isn't just about building a 432 Hz converter. It's about:

1. **Discovery through dual-track development** — Building two paths simultaneously reveals insights neither alone would uncover
2. **Systems thinking** — Understanding Android's audio architecture at multiple levels (kernel, HAL, framework)
3. **Practical audio DSP** — Real-time pitch-shift with minimal latency on mobile hardware
4. **Open exploration** — Contributing architecture insights back to the Android community

### What is 432 Hz?

432 Hz is an alternative tuning standard where A4 = 432 Hz (vs. modern standard A4 = 440 Hz). Some audio professionals and musicians advocate for 432 Hz for its purported harmonic properties.

## Quick Start

### Prerequisites
- Galaxy S25+ (or compatible Android device)
- Unlocked bootloader (for PATH-B)
- Linux development machine (Ubuntu 22.04+)
- 200GB free disk space (for AOSP build)

### Option 1: Install PATH-C (No ROM Flash Required)
```bash
# Coming in Phase 2
# Magisk module installation for stock Android
```

### Option 2: Build & Flash PATH-B (Custom ROM)
```bash
# Coming in Phase 2
# Full ROM compilation and flashing
```

## Development Phases

| Phase | Weeks | Focus |
|-------|-------|-------|
| 1 | 1-2 | Environment setup, repository scaffolding, DSP foundation |
| 2 | 3-4 | PATH-B AudioFlinger hooks, PATH-C Magisk module core |
| 3 | 5-6 | Bluetooth/codec handling, call audio interception |
| 4 | 7-8 | Performance optimization, real-world testing |
| 5 | 9-10 | Synthesis, discovery documentation, innovation extraction |

**Current Status:** Phase 1 (Project scaffolding) — You are here ✓

## Architecture

### High-Level Overview

```
AUDIO SOURCE (Spotify, YouTube, Calls, System)
    ↓
ANDROID AUDIO FRAMEWORK (AudioFlinger)
    ↓
[INSERTION POINT FOR AUDIOSHIFT]
    ├─ PATH-B: System-level (kernel/HAL)
    └─ PATH-C: Runtime-level (Magisk hook)
    ↓
REAL-TIME DSP PIPELINE
    ├─ PCM capture
    ├─ Pitch-shift to 432 Hz (-31.77 cents)
    ├─ Quality preservation
    └─ Re-encoding (Bluetooth, Wi-Fi)
    ↓
OUTPUT (Speaker, Bluetooth, Headphones, Calls)
```

[Read full architecture documentation](docs/ARCHITECTURE.md)

## Project Structure

```
audioshift/
├── shared/          # Device-agnostic DSP & testing
├── path_b_rom/      # Custom ROM implementation
├── path_c_magisk/   # Magisk module implementation
├── synthesis/       # Cross-track discoveries
├── docs/            # Complete documentation
├── scripts/         # Build and utility scripts
└── tests/           # Test suites
```

## Key Technologies

- **Audio DSP:** SoundTouch library (WSOLA pitch-shift algorithm)
- **Platforms:** AOSP, Magisk, Android HAL
- **Languages:** C++ (DSP), Kotlin (framework), Bash (scripts)
- **Targets:** Android 14+, Snapdragon 8 Elite processor

## Getting Involved

### For Developers
- [Getting Started Guide](docs/GETTING_STARTED.md)
- [Development Guide](docs/DEVELOPMENT_GUIDE.md)
- [API Reference](docs/API_REFERENCE.md)

### For Contributors
- [Contributing Guidelines](.github/CONTRIBUTING.md)
- [Code of Conduct](.github/CODE_OF_CONDUCT.md)

### For Researchers
- [Discovery Log](DISCOVERY_LOG.md)
- [Android Audio Architecture Deep-Dive](docs/ANDROID_INTERNALS.md)
- [Research Papers & Analysis](research/)

## Patent & IP Potential

This project explores novel approaches to system-level audio processing that may result in patentable innovations. See [PATENT_IDEAS.md](synthesis/PATENT_IDEAS.md)

## License

MIT License — See [LICENSE](LICENSE)

## Acknowledgments

Built on foundation of AOSP, SoundTouch, and Magisk projects.
Inspired by open-source audio engineering community.

---

## Next Steps

1. Set up development environment → [GETTING_STARTED.md](docs/GETTING_STARTED.md)
2. Unlock Galaxy S25+ bootloader → [Unlock Guide](docs/S25_BOOTLOADER_UNLOCK_STEPBYSTEP.md)
3. Clone this repository and begin Phase 2 implementation