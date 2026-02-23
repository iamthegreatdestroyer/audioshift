# AudioShift — Master Class Prompt for Claude Code

**Use this prompt in Claude Code (VS Code) to bootstrap the entire AudioShift project**

---

## HOW TO USE THIS PROMPT [REF:USAGE]

1. **Open VS Code**
2. **Install Claude Code extension** (if not already installed)
3. **Open the folder** where you want the audioshift repository (or create new folder)
4. **Open Claude Code chat** (click Claude icon or Cmd+Shift+A on Mac / Ctrl+Shift+A on Windows)
5. **Copy the entire "MASTER CLASS PROMPT" section below** (everything between the dashed lines)
6. **Paste into Claude Code chat**
7. **Press Enter and let Claude Code work**

Expected time: 10-15 minutes for complete scaffolding

---

## ============ BEGIN: MASTER CLASS PROMPT ============

You are the architectural lead for **AudioShift**, a groundbreaking dual-path Android audio conversion system. Your mission is to scaffold the complete project repository structure, create foundational files, and establish the technical framework for both PATH-B (Custom ROM) and PATH-C (Magisk Module) development.

### Context

**Project Name:** AudioShift
**Objective:** Real-time 432 Hz audio conversion for Android via two parallel implementation paths

**PATH-B:** Custom ROM with kernel-level audio pipeline modification
**PATH-C:** Magisk module with runtime audio interception

**Target Device:** Samsung Galaxy S25+
**Timeline:** 10-week parallel development with discovery-driven innovation

### Your Tasks

You will execute these tasks in order. After each major section, confirm completion before moving to the next.

---

## TASK 1: Repository Initialization & Structure [REF:TASK1]

### 1.1 Create Root Directory Structure

Create the following directory tree in the root of the project:

```
audioshift/
├── shared/
│   ├── dsp/
│   │   ├── src/
│   │   ├── include/
│   │   └── tests/
│   ├── audio_testing/
│   │   ├── src/
│   │   └── tests/
│   └── documentation/
├── path_b_rom/
│   ├── android/
│   │   ├── frameworks/av/
│   │   │   └── services/audioflinger/
│   │   ├── hardware/libhardware/
│   │   ├── device/samsung/s25plus/
│   │   └── build/
│   ├── kernel/
│   ├── build_scripts/
│   └── device_configs/
├── path_c_magisk/
│   ├── module/
│   │   ├── common/
│   │   ├── system/
│   │   │   ├── lib64/
│   │   │   └── vendor/etc/
│   │   └── META-INF/
│   ├── native/
│   ├── tools/
│   └── build_scripts/
├── synthesis/
├── ci_cd/
├── docs/
├── examples/
├── research/
├── tests/
│   ├── unit/
│   ├── integration/
│   └── performance/
├── scripts/
├── .github/
│   └── workflows/
└── (root-level config files)
```

**Action:** Create all directories listed above. Use `mkdir -p` equivalent for nested structures.

---

## TASK 2: Root-Level Configuration Files [REF:TASK2]

### 2.1 Create .gitignore

Create `.gitignore` in project root with Android/C++/AOSP-specific patterns:

```
# AOSP/Android build artifacts
/out/
*.apk
*.dex
*.class
*.jar
build/

# Compiled DSP libraries
*.so
*.a
*.o
*.os
*.pyc

# IDE & editor
.vscode/
.idea/
*.swp
*.swo
*~
.DS_Store

# Build system
*.gradle
.gradle/

# Environment
.env
.env.local
/vendor/
/system/

# Test artifacts
/test_results/
*.log

# Device-specific (secrets)
device_keys/
private_keys/

# Large binary files
*.zip
*.img
*.bin
```

### 2.2 Create LICENSE (MIT)

Create `LICENSE` file with MIT license text:

```
MIT License

Copyright (c) 2025 AudioShift Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
```

### 2.3 Create README.md (Main Project Overview)

Create `README.md` with comprehensive project overview:

```markdown
# AudioShift — Real-time 432 Hz Audio Conversion for Android

**Dual-path implementation of system-level audio pitch-shift to 432 Hz tuning on Android**

## Overview

AudioShift is an innovative exploration of Android audio architecture through 
parallel development of two complementary implementations:

- **PATH-B:** Custom Android ROM with kernel-level audio pipeline modification
- **PATH-C:** Magisk module for runtime audio interception on stock Android

Both paths deliver real-time 432 Hz conversion with different tradeoffs between 
coverage, latency, and compatibility.

## Why AudioShift?

### The Innovation Philosophy

AudioShift isn't just about building a 432 Hz converter. It's about:

1. **Discovery through dual-track development** — Building two paths simultaneously reveals insights neither alone would uncover
2. **Systems thinking** — Understanding Android's audio architecture at multiple levels (kernel, HAL, framework)
3. **Practical audio DSP** — Real-time pitch-shift with minimal latency on mobile hardware
4. **Open exploration** — Contributing architecture insights back to the Android community

### What is 432 Hz?

432 Hz is an alternative tuning standard where A4 = 432 Hz (vs. modern standard A4 = 440 Hz). 
Some audio professionals and musicians advocate for 432 Hz for its purported harmonic properties.

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

[See full structure](PROJECT_NAMING_AUDIOSHIFT.md#folder-structure)

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

This project explores novel approaches to system-level audio processing that may 
result in patentable innovations. See [PATENT_IDEAS.md](synthesis/PATENT_IDEAS.md)

## License

MIT License — See [LICENSE](LICENSE)

## Acknowledgments

Built on foundation of AOSP, SoundTouch, and Magisk projects.
Inspired by open-source audio engineering community.

---

## Next Steps

1. Set up development environment → [GETTING_STARTED.md](docs/GETTING_STARTED.md)
2. Unlock Galaxy S25+ bootloader → [Unlock Guide](S25_BOOTLOADER_UNLOCK_STEPBYSTEP.md)
3. Clone this repository and begin Phase 2 implementation
```

### 2.4 Create .editorconfig

Create `.editorconfig` for consistent code style:

```
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true

[*.cpp]
indent_size = 4
indent_style = space

[*.h]
indent_size = 4
indent_style = space

[*.java]
indent_size = 4
indent_style = space

[*.sh]
indent_size = 2
indent_style = space

[*.mk]
indent_size = 4
indent_style = space

[*.xml]
indent_size = 2
indent_style = space

[*.md]
trim_trailing_whitespace = false
```

### 2.5 Create CHANGELOG.md

Create `CHANGELOG.md` with version tracking template:

```markdown
# Changelog

All notable changes to AudioShift will be documented in this file.

## [Unreleased]

### Added
- Project repository structure
- Master documentation templates
- Build environment setup guides

### Changed
- Initial architecture planning

### Fixed
- (none yet)

## [0.0.1] - 2025-02-22

### Initial Release
- Project scaffolding complete
- Development environment documentation
- Master class prompts for CODE

---

## Format Guide

### Version Format
- **[X.Y.Z]** follows Semantic Versioning
  - X: Major version (breaking changes)
  - Y: Minor version (new features)
  - Z: Patch version (bug fixes)

### Categories
- **Added:** New features, modules
- **Changed:** Modifications to existing functionality
- **Deprecated:** Soon-to-be removed features
- **Removed:** Deleted features
- **Fixed:** Bug fixes
- **Security:** Security improvements
```

---

## TASK 3: Documentation Scaffolding [REF:TASK3]

### 3.1 Create Core Documentation Files

Create the following documentation structure in `docs/`:

#### docs/GETTING_STARTED.md

```markdown
# Getting Started with AudioShift

## Prerequisites

- Galaxy S25+ (Android 16)
- Unlocked bootloader
- Linux machine (Ubuntu 22.04 LTS)
- 200GB free disk space
- USB-C cable (data-capable)

## Quick Setup (10 minutes)

### Step 1: Clone Repository
\`\`\`bash
git clone https://github.com/YOUR_USERNAME/audioshift.git
cd audioshift
\`\`\`

### Step 2: Run Setup Script
\`\`\`bash
chmod +x scripts/setup_environment.sh
./scripts/setup_environment.sh
\`\`\`

### Step 3: Verify Installation
\`\`\`bash
./scripts/verify_environment.sh
\`\`\`

## What's Next?

- **PATH-B developers:** [Build Custom ROM](../path_b_rom/README_PATH_B.md)
- **PATH-C developers:** [Build Magisk Module](../path_c_magisk/README_PATH_C.md)
- **Researchers:** [Development Guide](DEVELOPMENT_GUIDE.md)

## Troubleshooting

[See TROUBLESHOOTING.md](TROUBLESHOOTING.md)
```

#### docs/ARCHITECTURE.md

```markdown
# AudioShift Architecture

## System Overview

### Audio Pipeline Hierarchy

\`\`\`
Application Layer (Spotify, YouTube, etc.)
    ↓
Android Framework (media_server, AudioTrack/AudioRecord)
    ↓
AudioFlinger (Audio Mixer/DSP Hub)
    ├─ [PATH-B INSERTION: Kernel/HAL Level]
    └─ [PATH-C INSERTION: Runtime Hook Level]
    ↓
Hardware Abstraction Layer (HAL)
    ├─ Audio Codec (WCD939x on S25+)
    ├─ Digital Amplifier (Cirrus Logic)
    └─ Bluetooth Module
    ↓
Hardware (Speaker, Bluetooth, Headphones)
```

### PATH-B: System-Level Integration
- **Where:** AudioFlinger pitch-shift hook
- **When:** Before codec encoding
- **Latency:** 2-5ms
- **Coverage:** 100% of audio

### PATH-C: Runtime Integration
- **Where:** Magisk module LD_PRELOAD hook
- **When:** After AudioFlinger output
- **Latency:** 10-15ms
- **Coverage:** 90% of audio

## Signal Flow Details

[See detailed diagrams in this document]

## Performance Characteristics

| Metric | PATH-B | PATH-C |
|--------|--------|--------|
| Latency | <5ms | 10-15ms |
| CPU Load | 3-5% | 6-10% |
| Coverage | 100% | 90%+ |
| Installation | ROM flash | Magisk install |
```

#### docs/DEVELOPMENT_GUIDE.md

```markdown
# Development Guide

## Setup Development Environment

### Prerequisites
\`\`\`bash
# Ubuntu 22.04 LTS
sudo apt-get update
sudo apt-get install -y \\
  git curl wget openssh-client \\
  build-essential zip zlib1g-dev \\
  python3 python3-pip ccache
\`\`\`

### Clone Audioshift Repository
\`\`\`bash
git clone https://github.com/YOUR_USERNAME/audioshift.git
cd audioshift
git checkout -b feature/your-feature-name
\`\`\`

## Build Process

### Build Shared DSP Library
\`\`\`bash
cd shared/dsp
mkdir build && cd build
cmake ..
make -j$(nproc)
\`\`\`

### Build PATH-B ROM
\`\`\`bash
cd path_b_rom
./build_scripts/build_rom.sh
\`\`\`

### Build PATH-C Magisk Module
\`\`\`bash
cd path_c_magisk
./build_scripts/build_module.sh
\`\`\`

## Code Organization

### Naming Conventions
- **C++ files:** snake_case.cpp
- **Header files:** snake_case.h
- **Directories:** snake_case/
- **Classes:** PascalCase
- **Functions:** camelCase
- **Constants:** UPPER_SNAKE_CASE

### Comment Style
- Document public APIs with Doxygen comments
- Include high-level intent, not just what code does
- Link to relevant architecture docs

### Git Workflow

1. Create feature branch: `git checkout -b feature/your-feature`
2. Make commits with clear messages
3. Push to fork: `git push origin feature/your-feature`
4. Create pull request with:
   - Clear description
   - Link to relevant issues
   - Testing results
   - Any performance impact

## Testing

### Run Unit Tests
\`\`\`bash
./scripts/run_unit_tests.sh
\`\`\`

### Run Integration Tests
\`\`\`bash
./scripts/run_integration_tests.sh
\`\`\`

### Performance Benchmarking
\`\`\`bash
./tests/performance/benchmark_latency.cpp
\`\`\`

## Documentation

- Update README for significant changes
- Add comments for complex algorithms
- Document discoveries in [DISCOVERY_LOG.md](../DISCOVERY_LOG.md)
- Reference [ANDROID_INTERNALS.md](ANDROID_INTERNALS.md) for deep-dive topics
```

#### docs/TROUBLESHOOTING.md

```markdown
# Troubleshooting Guide

## Common Issues

### Issue: "fastboot devices" returns empty
**Cause:** USB drivers not installed
**Solution:** [See S25+ Unlock Guide](../S25_BOOTLOADER_UNLOCK_STEPBYSTEP.md#troubleshooting)

### Issue: AOSP build fails
**Cause:** Missing dependencies or Java version mismatch
**Solution:** Verify Java 17+ installed: `java -version`

### Issue: Magisk module won't install
**Cause:** Incorrect permissions or module.prop syntax
**Solution:** Check Magisk logs: `adb shell cat /data/adb/magisk/magisk.log`

[See full troubleshooting section with detailed solutions]
```

### 3.2 Create Placeholder Documentation

Create empty but structured files for:
- `docs/API_REFERENCE.md` — DSP library API documentation
- `docs/ANDROID_INTERNALS.md` — Deep-dive on Android audio subsystem
- `docs/DEVICE_SUPPORT.md` — Device compatibility matrix
- `docs/FAQ.md` — Frequently asked questions

---

## TASK 4: Script Scaffolding [REF:TASK4]

### 4.1 Create Setup Script (scripts/setup_environment.sh)

```bash
#!/bin/bash

echo "=== AudioShift Development Environment Setup ==="
echo ""

# Check OS
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo "ERROR: This setup script requires Linux (Ubuntu 22.04+)"
    exit 1
fi

# Check if running in audioshift directory
if [ ! -f "README.md" ]; then
    echo "ERROR: Please run this script from the audioshift root directory"
    exit 1
fi

echo "[1/5] Installing system dependencies..."
sudo apt-get update > /dev/null 2>&1
sudo apt-get install -y \
  git curl wget openssh-client gnupg flex bison gperf build-essential \
  zip zlib1g-dev gcc-multilib g++-multilib libc6-dev-i386 \
  lib32ncurses5-dev x11-utils ccache libxml2-utils xsltproc unzip \
  fontconfig libfreetype6-dev libx11-dev libxext-dev libxrender-dev \
  libbz2-dev libesd0-dev libselinux1-dev gawk python3-mako \
  libwxgtk3.0-gtk3-dev ninja-build cmake android-tools-adb \
  android-tools-fastboot > /dev/null 2>&1

echo "[2/5] Verifying Java installation..."
JAVA_VERSION=$(java -version 2>&1 | grep -oP 'version "\K[0-9]+')
if [ "$JAVA_VERSION" -lt 17 ]; then
    echo "ERROR: Java 17+ required, found version $JAVA_VERSION"
    exit 1
fi
echo "✓ Java $JAVA_VERSION detected"

echo "[3/5] Creating build directories..."
mkdir -p shared/dsp/build
mkdir -p path_b_rom/out
mkdir -p path_c_magisk/out
mkdir -p test_results

echo "[4/5] Initializing git repository..."
git config user.name "AudioShift Developer" 2>/dev/null || true
git config user.email "dev@audioshift.local" 2>/dev/null || true

echo "[5/5] Verifying setup..."
if [ -d "shared/dsp" ] && [ -d "path_b_rom" ] && [ -d "path_c_magisk" ]; then
    echo ""
    echo "=== Setup Complete! ==="
    echo ""
    echo "Next steps:"
    echo "1. Read GETTING_STARTED.md"
    echo "2. Configure your Git credentials"
    echo "3. Choose your path: PATH-B (ROM) or PATH-C (Magisk)"
    echo ""
else
    echo "ERROR: Setup verification failed"
    exit 1
fi
```

### 4.2 Create Build Scripts

Create empty shell scripts in `scripts/` for later population:
- `build_all.sh` — Build both PATH-B and PATH-C
- `run_all_tests.sh` — Execute complete test suite
- `device_flash_rom.sh` — Flash PATH-B to device
- `device_install_magisk.sh` — Install PATH-C on device
- `verify_environment.sh` — Verify build environment

---

## TASK 5: Source File Scaffolding [REF:TASK5]

### 5.1 Create Shared DSP Library Structure

#### shared/dsp/include/audio_432hz.h

```cpp
#ifndef AUDIOSHIFT_AUDIO_432HZ_H
#define AUDIOSHIFT_AUDIO_432HZ_H

#include <cstdint>
#include <memory>

namespace audioshift {
namespace dsp {

/**
 * @brief Real-time audio pitch-shift to 432 Hz tuning frequency
 * 
 * Converts audio from 440 Hz tuning (A4=440) to 432 Hz tuning (A4=432)
 * using WSOLA (Waveform Similarity Overlap-Add) algorithm.
 * 
 * Conversion ratio: 432/440 ≈ 0.98182 (-31.77 cents)
 * 
 * @note This class is thread-safe for single-consumer usage.
 * @note Designed for real-time audio processing with minimal latency.
 */
class Audio432HzConverter {
public:
    /**
     * @brief Initialize converter
     * @param sampleRate Audio sample rate (Hz) - typically 48000
     * @param channels Number of audio channels (1=mono, 2=stereo)
     */
    Audio432HzConverter(int sampleRate = 48000, int channels = 2);
    
    ~Audio432HzConverter();
    
    /**
     * @brief Process audio buffer to 432 Hz pitch
     * @param buffer Input/output PCM audio buffer (int16 samples)
     * @param numSamples Number of samples in buffer
     * @return Actual samples processed
     */
    int process(int16_t* buffer, int numSamples);
    
    /**
     * @brief Set sample rate (may reset internal state)
     * @param sampleRate New sample rate in Hz
     */
    void setSampleRate(int sampleRate);
    
    /**
     * @brief Set pitch shift amount in semitones
     * @param semitones Pitch shift (-0.53 for 432 Hz conversion)
     */
    void setPitchShiftSemitones(float semitones);
    
    /**
     * @brief Get estimated latency from input to output
     * @return Latency in milliseconds
     */
    float getLatencyMs() const;
    
    /**
     * @brief Get estimated CPU usage
     * @return CPU usage percentage (0.0-100.0)
     */
    float getCpuUsagePercent() const;
    
private:
    class Impl;  // Pimpl pattern for hiding SoundTouch dependency
    std::unique_ptr<Impl> pImpl_;
};

}  // namespace dsp
}  // namespace audioshift

#endif  // AUDIOSHIFT_AUDIO_432HZ_H
```

#### shared/dsp/src/audio_432hz.cpp

```cpp
#include "audio_432hz.h"

// Placeholder implementation
// Will be expanded in Phase 2

namespace audioshift {
namespace dsp {

Audio432HzConverter::Audio432HzConverter(int sampleRate, int channels)
    : pImpl_(nullptr) {
    // Constructor stub
}

Audio432HzConverter::~Audio432HzConverter() {
    // Destructor stub
}

int Audio432HzConverter::process(int16_t* buffer, int numSamples) {
    // Implementation stub
    return numSamples;
}

void Audio432HzConverter::setSampleRate(int sampleRate) {
    // Stub
}

void Audio432HzConverter::setPitchShiftSemitones(float semitones) {
    // Stub
}

float Audio432HzConverter::getLatencyMs() const {
    return 15.0f;  // Placeholder
}

float Audio432HzConverter::getCpuUsagePercent() const {
    return 8.5f;  // Placeholder
}

}  // namespace dsp
}  // namespace audioshift
```

### 5.2 Create PATH-B README

#### path_b_rom/README_PATH_B.md

```markdown
# PATH-B: Custom Android ROM Implementation

## Overview

PATH-B implements real-time 432 Hz audio conversion at the Android OS level 
via modifications to AudioFlinger and audio HAL.

## Architecture

### Key Components

1. **AudioFlinger Modifications** (frameworks/av/services/audioflinger/)
   - Inject pitch-shift effect into audio mixer
   - Process before codec encoding

2. **Audio HAL Patch** (hardware/libhardware/audio/)
   - Low-level codec configuration
   - Hardware-specific optimizations

3. **Device Configuration** (device/samsung/s25plus/)
   - S25+ specific audio properties
   - Mixer path configuration

## Building PATH-B

[See build instructions in docs/DEVELOPMENT_GUIDE.md]

## Performance Targets

- **Latency:** <5ms
- **CPU Load:** <5%
- **Coverage:** 100% of audio
- **Supported Codecs:** All (SBC, AAC, aptX, LDAC)

## Testing

[See testing procedures in docs/DEVELOPMENT_GUIDE.md]

## Known Limitations

(To be documented during development)

## Discoveries

See [DISCOVERIES_PATH_B.md](DISCOVERIES_PATH_B.md) for architectural insights.
```

### 5.3 Create PATH-C README

#### path_c_magisk/README_PATH_C.md

```markdown
# PATH-C: Magisk Module Implementation

## Overview

PATH-C implements real-time 432 Hz audio conversion via Magisk module 
that hooks into Android's audio framework at runtime.

## Architecture

### Key Components

1. **Magisk Module Framework** (module/)
   - Module metadata (module.prop)
   - Installation scripts (install.sh, service.sh)
   - System property configuration

2. **Native Hook Library** (native/)
   - LD_PRELOAD mechanism for libaudioflinger
   - Runtime function interception
   - DSP pipeline injection

3. **Audio Effect Configuration** (module/system/vendor/etc/)
   - Audio effects XML registration
   - Policy configuration

## Installation

### Prerequisites
- Rooted device (via Magisk)
- Magisk 20000+
- Android 11+

### Install Steps
```bash
# Create flashable zip
./build_scripts/build_module.sh

# Flash via Magisk Manager or:
adb push out/audioshift_magisk.zip /sdcard/
adb shell "magisk --install-module /sdcard/audioshift_magisk.zip"
adb reboot
```

## Performance Targets

- **Latency:** 10-15ms
- **CPU Load:** <10%
- **Coverage:** 90%+ of audio
- **Android Versions:** 11, 12, 13, 14

## Testing

[See testing procedures in docs/DEVELOPMENT_GUIDE.md]

## Known Limitations

- Cannot intercept all VoIP call types
- Some apps may bypass audio system

## Discoveries

See [DISCOVERIES_PATH_C.md](DISCOVERIES_PATH_C.md) for architectural insights.
```

---

## TASK 6: Discovery Log Initialization [REF:TASK6]

### 6.1 Create DISCOVERY_LOG.md

Create main project discovery log:

```markdown
# AudioShift Discovery Log

**A living document of insights, breakthroughs, and unexpected findings.**

## Philosophy

This project operates under the principle that **parallel development creates 
discovery opportunities that single-path development cannot access**. 

As we build both PATH-B and PATH-C simultaneously, we'll:
1. Document surprising findings
2. Identify cross-track synergies
3. Extract novel insights about Android audio architecture
4. Potentially discover new technologies or optimizations

## Week 1 (Setup Phase)

### Entry 1: Project Initialization
**Date:** 2025-02-22
**Type:** Project Start

**Discovery:** Complete repository structure scaffolded
**Impact:** Ready for Phase 2 implementation
**Next Steps:** Begin AudioFlinger investigation (PATH-B) and Magisk hooking research (PATH-C)

### Entry 2: (To be filled during development)

---

## Entry Template

Use this template for all discoveries:

\`\`\`
### Entry N: [Title]
**Date:** YYYY-MM-DD
**Type:** [Breakthrough | Bottleneck | Synergy | Design Decision | Unexpected Result]

**Discovery:** [What did we find?]

**Path Impact:** [PATH-B / PATH-C / Both / Neither]

**Significance:** [How does this matter? Patent potential? Community contribution?]

**Next Steps:** [What should we do with this finding?]

**Technical Details:** [Optional: deep technical explanation]
\`\`\`

---

## Cross-Track Insights (Will Populate During Development)

### From PATH-B to PATH-C

(Section for findings from ROM development that benefit module development)

### From PATH-C to PATH-B

(Section for findings from Magisk development that benefit ROM development)

---

## Patent Ideas (Will Populate During Development)

(Notable discoveries that may warrant patent applications)

---

## Community Contributions

(Insights valuable to broader Android developer community)

---

## Timeline of Major Discoveries

(Will be maintained as project progresses)
```

### 6.2 Create Weekly Sync Template

Create `WEEKLY_SYNC_TEMPLATE.md`:

```markdown
# Weekly Sync — Week [X]

**Date:** YYYY-MM-DD
**Duration:** 1 hour
**Attendees:** PATH-B Lead, PATH-C Lead, Architect

## Executive Summary

(Brief overview of the week's progress)

---

## PATH-B Status Report

### What Was Built
- [ ] Task 1
- [ ] Task 2

### Blockers & Challenges
- **Blocker 1:** Description and current approach
- **Blocker 2:** Description and current approach

### Metrics
- Code commits: [X]
- Test coverage: [X]%
- Build success rate: [X]%

### Questions for PATH-C Team
- **Q1:** Description

---

## PATH-C Status Report

### What Was Built
- [ ] Task 1
- [ ] Task 2

### Blockers & Challenges
- **Blocker 1:** Description and current approach

### Metrics
- Code commits: [X]
- Test coverage: [X]%
- Build success rate: [X]%

### Questions for PATH-B Team
- **Q1:** Description

---

## Synthesis & Discoveries

### Unexpected Synergies
- Finding 1 from PATH-B could enhance PATH-C in [way]
- Finding 1 from PATH-C could enhance PATH-B in [way]

### New Innovation Opportunities
- [Idea emerged from friction between paths]
- [Novel approach discovered]

### Architecture Insights
- [New understanding of Android audio]
- [Codec behavior pattern identified]

---

## Decisions & Pivots

### Should Either Track Adjust Course?
- [ ] Yes, based on: [findings]
- [ ] No, current approach remains optimal

### Resource Allocation Changes?
- [ ] Additional engineers needed
- [ ] Different expertise required
- [ ] Resources remain stable

---

## Next Week Priorities

### PATH-B (Weeks X-Y)
1. [Priority 1]
2. [Priority 2]
3. [Priority 3]

### PATH-C (Weeks X-Y)
1. [Priority 1]
2. [Priority 2]
3. [Priority 3]

### Shared/Synthesis (Weeks X-Y)
1. [Priority 1]
2. [Priority 2]

---

## Metrics Dashboard

| Metric | Previous Week | This Week | Target |
|--------|---|---|---|
| ROM Build Success Rate | X% | X% | 95%+ |
| Module Test Pass Rate | X% | X% | 95%+ |
| Average Latency (PATH-B) | Xms | Xms | <5ms |
| Average Latency (PATH-C) | Xms | Xms | <15ms |
| CPU Usage (PATH-B) | X% | X% | <5% |
| CPU Usage (PATH-C) | X% | X% | <10% |

---

## Action Items

- [ ] [ACTION] — Owner: [Name] — Due: [Date]
- [ ] [ACTION] — Owner: [Name] — Due: [Date]

---

## Notes & Discussion

(Free-form notes from sync meeting)
```

---

## TASK 7: Git Repository Initialization [REF:TASK7]

### 7.1 Initialize Git

```bash
# If not already initialized
git init

# Configure user
git config user.name "Your Name"
git config user.email "your.email@example.com"

# Create initial commit
git add .
git commit -m "Initial AudioShift project scaffolding

- Complete directory structure for PATH-B and PATH-C
- Documentation templates and guides
- Build script stubs
- Discovery log framework
- Development environment setup
- Ready for Phase 2 implementation"

# Create main branch (if not already main)
git branch -M main

# (Do NOT push to GitHub yet — you'll do that manually)
```

---

## TASK 8: Final Verification Checklist [REF:TASK8]

Verify the following exist:

- [ ] Directory structure complete (all 15+ major directories)
- [ ] Root-level files: README.md, LICENSE, .gitignore, CHANGELOG.md, .editorconfig
- [ ] Documentation: All docs/*.md files created
- [ ] Scripts: All scripts/*.sh files created (executable)
- [ ] Source code: Placeholder .cpp/.h files in shared/dsp/
- [ ] PATH-B: README_PATH_B.md, DISCOVERIES_PATH_B.md
- [ ] PATH-C: README_PATH_C.md, DISCOVERIES_PATH_C.md
- [ ] Discovery Log: DISCOVERY_LOG.md, WEEKLY_SYNC_TEMPLATE.md
- [ ] Git: Repository initialized with initial commit

---

## SUCCESS CRITERIA [REF:SUCCESS]

When complete, you should be able to:

✅ Navigate entire directory structure with clear purpose for each folder
✅ Read comprehensive README understanding project scope
✅ Follow getting started guide to verify environment
✅ Access complete documentation for all components
✅ View git history showing clean initial commit
✅ Find placeholder files ready for Phase 2 implementation
✅ Access discovery log ready for recording findings

---

## NEXT IMMEDIATE STEPS [REF:FINAL-NEXT]

Once this scaffolding is complete:

1. **Create GitHub Repository**
   - New public repo named "audioshift"
   - Initialize with README
   - Add topics: android, audio, dsp, 432hz, magisk

2. **Push to GitHub**
   ```bash
   git remote add origin https://github.com/YOUR_USERNAME/audioshift.git
   git branch -M main
   git push -u origin main
   ```

3. **Verify on GitHub**
   - Check all files are present
   - Verify README renders correctly
   - Confirm branch structure

4. **Begin Phase 2**
   - Start AudioFlinger investigation (PATH-B)
   - Begin Magisk hooking research (PATH-C)
   - Schedule first weekly sync

---

## ============ END: MASTER CLASS PROMPT ============

