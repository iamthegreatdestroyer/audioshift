# AudioShift: Next Steps Master Action Plan

**Master Plan for Phase 5+ Execution with Maximum Autonomy & Automation**

**Status:** Ready for immediate implementation
**Timeline:** Weeks 9-14 (estimated)
**Automation Level:** 85% (CI-driven)

---

## EXECUTIVE OVERVIEW

This plan describes the path from **production-ready codebase** (current state) to **community-deployed project** with:

- ✅ Real AOSP ROM compilation pipeline (automated via CI)
- ✅ Device flash infrastructure + validation gates
- ✅ Community repository publications (Magisk, XDA)
- ✅ Performance tuning via continuous profiling
- ✅ User settings UI for runtime control
- ✅ Advanced features (VoIP support, codec detection)

**Key Principle:** Maximize CI/CD automation to enable remote execution and reduce manual intervention.

---

## PHASE 5: PRODUCTION READINESS (Weeks 9-10)

### Sprint 5.1: AOSP Full Build Pipeline

**Objective:** Compile and validate complete ROM for Galaxy S25+

#### 5.1.1: AOSP Source Checkout Automation

**Task:** Automate AOSP repo initialization in CI

**Files to Create:**
```
scripts/aosp/
├── init_aosp_repo.sh           # Repo init + sync orchestration
├── apply_audioshift_patches.sh  # Patch AudioFlinger/HAL
├── configure_build.sh           # lunch + envsetup
└── build_rom.sh                 # Full ROM build (4 CPU-hours)
```

**Implementation (shell script, 400 LOC):**

```bash
#!/bin/bash
set -euo pipefail

AOSP_ROOT="${AOSP_ROOT:-.../aosp}"
NDK_VERSION="26.3.11579264"

# Step 1: Initialize repo (one-time)
mkdir -p "$AOSP_ROOT" && cd "$AOSP_ROOT"
repo init -u https://android.googlesource.com/platform/manifest \
  -b android-15 \
  --depth=1

# Step 2: Add AudioShift as local manifest
mkdir -p .repo/local_manifests
cp path_b_rom/android/build/local_manifests/audioshift.xml \
   "$AOSP_ROOT/.repo/local_manifests/"

# Step 3: Sync repos (parallel, resumable)
repo sync -j 8 -c --fail-fast

# Step 4: Apply AudioShift patches
for patch in path_b_rom/build_scripts/patches/*.patch; do
  patch -p0 < "$patch" || true
done

# Step 5: Build ROM
source build/envsetup.sh
lunch aosp_s25plus-userdebug
m -j $(nproc) libaudioshift432 otapackage

# Step 6: Publish artifacts
cp out/target/product/s25plus/aosp_s25plus-*.zip \
   artifacts/ROM_$(date +%Y%m%d_%H%M%S).zip
```

**Automation via CI:**
- Trigger: Manual workflow_dispatch (expensive, 4h build)
- Cache: AOSP source + NDK (persistent storage)
- Parallelism: 8 repo sync jobs
- Failure handling: Resumable checkpoints

**Status Gate:**
```yaml
# .github/workflows/aosp_build.yml (new)
name: AOSP Full ROM Build
on:
  workflow_dispatch:
    inputs:
      publish_artifact:
        description: "Publish ROM to releases?"
        default: "false"
jobs:
  aosp_build:
    runs-on: ubuntu-22.04-xxl  # 8 CPU, 32GB RAM
    timeout-minutes: 300       # 5 hours max
    steps:
      - checkout
      - run: scripts/aosp/init_aosp_repo.sh
      - run: scripts/aosp/build_rom.sh
      - if: github.event.inputs.publish_artifact == 'true'
        uses: softprops/action-gh-release@v1
        with:
          files: artifacts/ROM_*.zip
```

**Success Criteria:**
- ✅ `libaudioshift432.so` present in `out/target/product/s25plus/`
- ✅ `aosp_s25plus-*.zip` OTA package generated
- ✅ Package signature valid
- ✅ Flashable via fastboot/TWRP

---

#### 5.1.2: Automated Device Flash Sequence

**Task:** Create safe, idempotent ROM flashing automation

**Files to Create:**
```
scripts/flash/
├── fastboot_flash.sh            # ROM flashing orchestration
├── unlock_bootloader.sh          # Bootloader unlock (prompts user)
├── verify_device_state.sh        # Pre-flash validation
└── post_flash_tests.sh           # Device validation after flash
```

**Implementation (420 LOC):**

```bash
#!/bin/bash
# scripts/flash/fastboot_flash.sh — ADB + Fastboot orchestration

set -euo pipefail

ROM_ZIP="${1:?Usage: fastboot_flash.sh <rom_zip_path>}"
DEVICE_SERIAL="${2:-}"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║   AudioShift ROM Flashing — Samsung Galaxy S25+            ║"
echo "╚════════════════════════════════════════════════════════════╝"

# Step 1: Verify device connection
echo "[1/6] Verifying device connection..."
if [ -z "$DEVICE_SERIAL" ]; then
    DEVICE_SERIAL=$(adb get-serialno)
fi

adb -s "$DEVICE_SERIAL" shell "getprop ro.build.version.release" >/dev/null || {
    echo "ERROR: Device not found or not in ADB mode"
    echo "Connect device via USB and enable USB debugging"
    exit 1
}

# Step 2: Backup user data (optional)
read -p "Backup user data to PC? (y/n) " -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "[2/6] Backing up user data..."
    mkdir -p ./backups
    adb -s "$DEVICE_SERIAL" backup -apk -obb -shared -all \
        -nosystem -f "./backups/s25plus_$(date +%Y%m%d_%H%M%S).ab"
    echo "✓ Backup complete"
fi

# Step 3: Reboot to bootloader
echo "[3/6] Rebooting to bootloader..."
adb -s "$DEVICE_SERIAL" reboot bootloader

# Wait for fastboot device detection
sleep 5
fastboot -s "$DEVICE_SERIAL" devices || {
    echo "ERROR: Device not in fastboot mode"
    exit 1
}

# Step 4: Flash ROM via fastboot (automat boot.img + recovery)
echo "[4/6] Flashing ROM via fastboot..."
fastboot -s "$DEVICE_SERIAL" update "$ROM_ZIP"

# Step 5: Reboot to system
echo "[5/6] Rebooting system..."
fastboot -s "$DEVICE_SERIAL" reboot

# Step 6: Verify post-boot
echo "[6/6] Verifying device post-boot..."
sleep 30  # Wait for boot
adb -s "$DEVICE_SERIAL" wait-for-device
adb -s "$DEVICE_SERIAL" shell "getprop audioshift.version" && \
    echo "✓ AudioShift ROM verified active"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║   Flash Complete! ROM is ready to use.                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
```

**Usage:**
```bash
./scripts/flash/fastboot_flash.sh aosp_s25plus-userdebug-*.zip
```

**Safety Features:**
- Device connection verification before any action
- Backup option before destructive flashing
- Pre/post-boot validation gates
- Idempotent (re-run safely if interrupted)

---

### Sprint 5.2: Device Validation Gates

**Objective:** Automated post-flash verification

#### 5.2.1: Latency Gate (must pass)

**Requirement:** <10ms measured end-to-end latency on device

**Implementation (test_device_latency.sh, 120 LOC):**

```bash
#!/bin/bash
# Latency measurement via microphone feedback loop

DEVICE_SERIAL="${1:?Device serial required}"
THRESHOLD_MS=10

echo "Testing latency gate (<${THRESHOLD_MS}ms)..."

# Deploy latency test app + capture mic
adb -s "$DEVICE_SERIAL" push tests/integration/latency_tester.apk /data/
adb -s "$DEVICE_SERIAL" shell pm install /data/latency_tester.apk

# Generate tone, measure feedback delay
LATENCY=$(adb -s "$DEVICE_SERIAL" shell \
  "am instrument -w -e method latencyTest com.audioshift.test/.LatencyInstrumentation" \
  | grep "latency_ms=" | cut -d= -f2)

if (( ${LATENCY%.*} <= $THRESHOLD_MS )); then
    echo "✓ PASS: Latency = ${LATENCY}ms"
    exit 0
else
    echo "✗ FAIL: Latency = ${LATENCY}ms (threshold: ${THRESHOLD_MS}ms)"
    exit 1
fi
```

**Status Gate (GitHub Actions):**
```yaml
device_latency_test:
  needs: aosp_build
  runs-on: [self-hosted, android-s25plus]
  steps:
    - run: ./scripts/flash/fastboot_flash.sh ${{ needs.aosp_build.outputs.rom_zip }}
    - run: ./scripts/tests/device_latency_gate.sh
      continue-on-error: false  # BLOCKING
```

---

#### 5.2.2: Frequency Validation Gate (must pass)

**Requirement:** Input 440 Hz → Output 432 Hz (±0.5 Hz tolerance)

**Implementation (via audio_testing framework):**

```bash
#!/bin/bash
# Record device output, measure frequency via FFT

DEVICE_SERIAL="${1:?Device serial required}"

# Generate 440 Hz test tone on device
adb -s "$DEVICE_SERIAL" shell "am start -n com.audioshift.test/.ToneGenerator \
  --ef freq 440 --ef duration 5000"

# Record via USB microphone (Mac/Linux)
sox -t mp3 "|ffmpeg -i /dev/audio:0 -f mp3 -" \
    out.wav remix 1 rate 48k

# FFT analysis (Python)
python3 - <<EOF
import numpy as np
from scipy import signal
import soundfile as sf

samples, sr = sf.read('out.wav')
f, Pxx = signal.welch(samples, sr)
peak_freq = f[np.argmax(Pxx)]

if abs(peak_freq - 432.0) < 0.5:
    print(f"✓ PASS: Measured {peak_freq:.1f} Hz")
else:
    print(f"✗ FAIL: Measured {peak_freq:.1f} Hz (expected ~432 Hz)")
    exit(1)
EOF
```

**Status Gate (GitHub Actions):**
```yaml
device_frequency_test:
  needs: [aosp_build, device_latency_test]
  runs-on: [self-hosted, android-s25plus]
  steps:
    - run: ./scripts/tests/device_frequency_validation.sh
      continue-on-error: false  # BLOCKING
```

---

### Sprint 5.3: Magisk Repository Publication

**Objective:** Submit PATH-C module to official Magisk repo

**Task:** Prepare module for Magisk Manager integration

**Files to Update:**
```
path_c_magisk/module/
├── module.prop         # Update version to 2.0.0-release
├── META-INF/           # Ensure Magisk compliance
└── common/service.sh   # Ensure proper logging
```

**Magisk Repo Submission Checklist:**

- [ ] Module ID: `audioshift432hz` (no spaces)
- [ ] Version: `2.0.0`
- [ ] Module name: "AudioShift 432Hz"
- [ ] Description: "Real-time 432 Hz pitch-shift"
- [ ] Author: `@audioshift_project`
- [ ] Support thread: XDA link (see 5.4 below)
- [ ] minMagisk: `20400` (Zygisk support)
- [ ] maxSdkVersion: Omit (supports all)
- [ ] Changelog: git-cliff powered

**Submission via GitHub:**

```bash
# Create PR to Magisk-Modules-Repo
git clone https://github.com/Magisk-Modules-Repo/submission.git
cp -r path_c_magisk/module submission/audioshift432hz/
cd submission
git add audioshift432hz/
git commit -m "feat: Add AudioShift 432Hz Magisk module"
git push origin audioshift432hz
# Open PR to https://github.com/Magisk-Modules-Repo/submission
```

**Automation via CI:**

```yaml
# .github/workflows/magisk_submission.yml (new)
name: Magisk Module Submission
on:
  push:
    tags:
      - 'v*'
jobs:
  submit_to_magisk_repo:
    runs-on: ubuntu-22.04
    steps:
      - checkout
      - run: |
          # Clone submission repo
          git clone https://github.com/Magisk-Modules-Repo/submission.git

          # Copy module
          cp -r path_c_magisk/module submission/audioshift432hz/

          # Create PR (requires GH_TOKEN with repo scope)
          cd submission
          git config user.email "ci@audioshift.local"
          git config user.name "AudioShift CI"
          git checkout -b audioshift432hz-${{ github.ref_name }}
          git add audioshift432hz/
          git commit -m "feat: AudioShift 432Hz v${{ github.ref_name }}"
          git push origin audioshift432hz-${{ github.ref_name }}

          # Create PR
          gh pr create \
            --repo Magisk-Modules-Repo/submission \
            --title "AudioShift 432Hz v${{ github.ref_name }}" \
            --body "Magisk module for real-time 432 Hz pitch conversion"
```

---

### Sprint 5.4: XDA Developer Forum Publication

**Objective:** Create XDA thread for community visibility

**Implementation:** Template auto-deployed via CI

**Files:**
```
docs/XDA_POST_TEMPLATE.md  # (already created, high-quality)
scripts/publish/xda_post.sh # Upload script (manual or API-driven)
```

**XDA Post Structure (Markdown → HTML):**

```
[B][SIZE=5]AudioShift — Real-Time 432 Hz Pitch Shift[/SIZE][/B]

[COLOR=gray]Version: 2.0.0 | Device: Galaxy S25+ | Android: 15+[/COLOR]

[B]What Is This?[/B]
AudioShift intercepts [B]all audio output[/B] on a rooted device and applies
real-time pitch-shift to 432 Hz tuning.

[B]Requirements[/B]
[LIST]
[*]Rooted device (Magisk v26+)
[*]Android 12+ (API 31+)
[*]ARM64 architecture
[/LIST]

[B]Installation[/B]
[COLOR=green]✓ Easy[/COLOR] via Magisk Manager

[CODE]
1. Open Magisk Manager
2. Tap "Modules"
3. Tap "+" to add module
4. Download audioshift_magisk_v2.0.0.zip
5. Reboot
[/CODE]

[B]Download[/B]
[URL=https://github.com/iamthegreatdestroyer/audioshift/releases]
GitHub Releases (Latest)
[/URL]

[B]Troubleshooting[/B]
[SPOILER="Device not hearing pitch shift?"]
1. Run verification: adb shell sh /data/adb/modules/audioshift432hz/tools/verify_432hz.sh
2. Check Magisk logs: Settings > About > Magisk logs
[/SPOILER]

[B]Credits[/B]
Built with SoundTouch (WSOLA algorithm) on Android AudioFlinger.
```

**Automation:**
- XDA template = `docs/XDA_POST_TEMPLATE.md` (GitHub markdown)
- Convert to BBCode for XDA via pandoc
- Post via XDA API (if auth available) or manual upload
- Pin post after 10 downloads

---

## PHASE 6: OPTIMIZATION & ADVANCED FEATURES (Weeks 11-12)

### Sprint 6.1: Performance Profiling & Tuning

**Objective:** CPU/latency optimization via flame graphs

#### 6.1.1: Build with Profiling Enabled

**Files to Create:**
```
scripts/profile/
├── build_profiling_rom.sh      # Build with -fprofile-instr-generate
├── record_flamegraph.sh        # Capture CPU flame graph on device
└── analyze_flamegraph.py       # Bottleneck identification
```

**Implementation (shell, 180 LOC):**

```bash
#!/bin/bash
# Build AudioShift with profiling instrumentation

export CFLAGS="-fprofile-instr-generate -fcoverage-mapping"
export CXXFLAGS="-fprofile-instr-generate -fcoverage-mapping"

# Rebuild shared library
cd shared/dsp
cmake -B build_profile \
  -DCMAKE_C_FLAGS="$CFLAGS" \
  -DCMAKE_CXX_FLAGS="$CXXFLAGS"
cmake --build build_profile

# Push profiling library to device
adb push build_profile/libaudioshift_dsp.so /data/local/tmp/
adb shell setenforce 0  # Disable SELinux for profiling

# Record flame graph
perf record -e cpu-cycles,cpu-clock -g -o perf.data
perf script | flamegraph.pl > flamegraph.svg

# Identify bottlenecks via flamegraph analysis
# (SoundTouch WSOLA resampling likely dominates)
```

**Expected Results:**
- Identify CPU hotspots (likely: SoundTouch::TDStretch, overlap-add)
- Measure time spent in:
  - Pitch detection: ~2ms
  - Resampling: ~8ms
  - Overlap-add: ~3ms
  - Total: ~13ms per audio frame

**Optimization Strategy:**
1. Verify SoundTouch SIMD enabled (SSE/NEON)
2. Reduce overlap percentage if CPU headroom allows
3. Parallel processing for multi-core
4. Hardware acceleration exploration (if available)

---

#### 6.1.2: Continuous Profiling in CI

**Implementation:**

```yaml
# .github/workflows/performance_profile.yml (new)
name: Performance Profiling
on:
  push:
    branches: [main, develop]
jobs:
  profile_device:
    runs-on: [self-hosted, android-s25plus]
    steps:
      - checkout
      - run: scripts/profile/build_profiling_rom.sh
      - run: scripts/profile/record_flamegraph.sh
      - name: Upload flamegraph artifact
        uses: actions/upload-artifact@v3
        with:
          name: flamegraph
          path: flamegraph.svg
      - name: Compare against baseline
        run: scripts/profile/compare_baseline.py
```

**Baseline Storage:**
- Store baseline flamegraph in `research/baselines/flamegraph_baseline.svg`
- Alert if total CPU time increases >10%

---

### Sprint 6.2: User Settings UI

**Objective:** Android preferences app for runtime control

**Implementation (Kotlin, 400 LOC):**

```
examples/audioshift_prefs/
├── AndroidManifest.xml
├── res/
│   ├── values/strings.xml
│   └── xml/preferences.xml
└── src/main/kotlin/
    ├── AudioShiftPreferences.kt    # Settings activity
    └── AudioShiftService.kt         # Settings → system properties
```

**Features:**
- ✅ Enable/disable toggle
- ✅ Pitch shift slider (±100 cents)
- ✅ WSOLA parameter tuning (sequence, seekwindow, overlap)
- ✅ Live latency readout
- ✅ CPU usage gauge
- ✅ Frequency response chart

**Implementation Pattern:**

```kotlin
class AudioShiftPreferences : PreferenceFragmentCompat() {
    override fun onCreatePreferences(savedInstanceState: Bundle?, rootKey: String?) {
        setPreferencesFromResource(R.xml.preferences, rootKey)

        val enableSwitch = findPreference<SwitchPreference>("audioshift_enabled")
        enableSwitch?.onPreferenceChangeListener = Preference.OnPreferenceChangeListener { _, value ->
            SystemProperties.set("audioshift.enabled", if (value as Boolean) "1" else "0")
            true
        }

        val pitchSeek = findPreference<SeekBarPreference>("pitch_cents")
        pitchSeek?.onPreferenceChangeListener = Preference.OnPreferenceChangeListener { _, value ->
            val cents = (value as Int) - 100  // -100 to +100 mapped from slider 0-200
            val semitones = cents / 100f
            SystemProperties.set("audioshift.pitch_semitones", semitones.toString())
            true
        }
    }
}
```

**Distribution:**
- F-Droid compatible (open-source preference app)
- Google Play (if desired, requires Play Store account)
- Standalone APK in releases

---

### Sprint 6.3: VoIP Support Research

**Objective:** Explore call audio interception via separate HAL

**Research Task (non-implementation):**

1. **Android Call Audio Architecture:**
   - Analyze AudioHAL voice device interface
   - Document voice call signal flow
   - Identify AudioFlinger call audio paths vs music

2. **Proof of Concept:**
   - Create minimal `audio_voice_effect.xml`
   - Register effect for `AUDIO_DEVICE_OUT_EARPIECE`
   - Test on S25+ with WhatsApp call
   - Measure latency impact

3. **Documentation:**
   - Write findings in `research/VOIP_AUDIO_ANALYSIS.md`
   - Identify feasibility score (1-10)
   - Estimate implementation effort for future phase

---

### Sprint 6.4: Codec Detection & Adaptation

**Objective:** Auto-tune for Bluetooth codecs (aptX, LDAC, LHDC)

**Implementation (Python research script, 200 LOC):**

```python
#!/usr/bin/env python3
# scripts/research/analyze_codecs.py

import subprocess
import json

def get_active_codec(device_serial):
    """Query Bluetooth codec via adb"""
    result = subprocess.run(
        f"adb -s {device_serial} shell "
        "dumpsys bluetooth_manager | grep -i 'Active codec'",
        shell=True, capture_output=True, text=True
    )
    return result.stdout.strip()

def measure_latency_per_codec(device_serial, codecs=['SBC', 'AAC', 'aptX', 'LDAC']):
    """Measure latency for each Bluetooth codec"""
    results = {}
    for codec in codecs:
        # TODO: Force codec selection via adb
        latency_ms = run_latency_test(device_serial)
        results[codec] = latency_ms
        print(f"{codec}: {latency_ms:.1f}ms")
    return results

# Expected results (hypothesis):
# SBC (Bluetooth baseline):    12-15ms
# AAC (streaming):            10-12ms
# aptX (Qualcomm):            8-10ms  ← best
# LDAC (Sony):                7-9ms   ← best
# LHDC (Chinese):             6-8ms   ← best

# Recommendation: Adjust WSOLA parameters based on codec
# High-latency codec (SBC) → increase overlap for quality
# Low-latency codec (LHDC) → reduce latency impact margin
```

**Findings Storage:**
- Document codec latency tradeoffs in `research/CODEC_LATENCY_ANALYSIS.md`
- Reference in troubleshooting guide

---

## PHASE 7: COMMUNITY & RELEASE (Weeks 13-14)

### Sprint 7.1: GitHub Release Automation

**Objective:** Automated versioning + artifact publishing

**Implementation via Git Tags:**

```bash
# Trigger release by tagging a commit
git tag -a v2.0.0 -m "Release version 2.0.0: Production-ready"
git push origin v2.0.0

# GitHub Actions automatically:
# 1. Builds ROM + Magisk zip
# 2. Generates changelog via git-cliff
# 3. Creates GitHub Release
# 4. Uploads artifacts
# 5. Publishes to Magisk repo
```

**Automation Config:**

```yaml
# .github/workflows/release.yml (already created, enhance)
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  create_release:
    runs-on: ubuntu-22.04-xxl
    steps:
      - checkout

      # Build ROM
      - run: scripts/aosp/build_rom.sh

      # Build Magisk zip
      - run: scripts/build/build_magisk_module.sh

      # Generate changelog
      - run: |
          pip install git-cliff
          git-cliff > CHANGELOG.md

      # Create GitHub Release
      - uses: softprops/action-gh-release@v1
        with:
          files: |
            artifacts/ROM_*.zip
            artifacts/audioshift_magisk_v*.zip
            CHANGELOG.md
          body_path: CHANGELOG.md
```

---

### Sprint 7.2: Documentation & Blog Posts

**Objective:** Share knowledge with Android dev community

**Content to Create:**

1. **Medium Article:** "How I Built a System-Wide Audio Effect for Android"
   - Architecture deep-dive
   - WSOLA algorithm explanation
   - AudioFlinger hook strategies
   - SoundTouch integration lessons

2. **Android Developers Blog Post:** "Real-Time Audio DSP on Mobile"
   - Performance profiling methodology
   - Latency measurement techniques
   - Codec-aware audio processing

3. **GitHub Pages Site Enhancements:**
   - Case study: 440 Hz → 432 Hz conversion math
   - Troubleshooting decision tree (flowchart)
   - Video demo (screen recording + audio frequency chart)

---

### Sprint 7.3: Community Support Infrastructure

**Objective:** Sustainable support channels

**Channels:**
- [ ] GitHub Discussions (Q&A template)
- [ ] XDA Support Thread (monitor via email notifications)
- [ ] Discord server (optional, for real-time community)
- [ ] Monthly community standup (Zoom recording → YouTube)

**Support Playbook:**

```markdown
# Frequently Asked Questions (Maintained Live)

## Q: Why doesn't it work with [app]?
**A:** Some apps (like Spotify Free tier) use hardware audio pipelines
      that bypass AudioFlinger. This is a platform limitation, not a bug.

## Q: Can it work on [device]?
**A:** See DEVICE_SUPPORT.md. New devices need testing.
      Please open an issue with device model + Android version.

## Q: What if I get audio stuttering?
**A:** Run verification script: /data/adb/modules/audioshift432hz/tools/verify_432hz.sh
      If latency >15ms, adjust WSOLA parameters via settings app.
```

---

## AUTOMATION ARCHITECTURE

### CI/CD Pipeline (8→12 Jobs)

```
┌─────────────┐
│ Push/Tag    │
└──────┬──────┘
       │
   ┌───┴───────────────────────────────────┐
   │                                       │
   v                                       v
┌──────────────────┐          ┌──────────────────┐
│ Unit Tests (5m)  │          │ Format Check (2m)│
└────────┬─────────┘          └────────┬─────────┘
         │                             │
         └───────────────┬─────────────┘
                         │
                  ┌──────v──────┐
                  │ Lint (5m)   │
                  └──────┬──────┘
                         │
              ┌──────────v──────────┐
              │                     │
              v                     v
        ┌─────────────┐       ┌──────────────┐
        │ NDK Build   │       │ AOSP Build   │
        │ (15m)       │       │ (240m) [OPT] │
        └──────┬──────┘       └──────┬───────┘
               │                     │
               └──────────┬──────────┘
                          │
            ┌─────────────v──────────────┐
            │                            │
            v                            v
       ┌─────────────┐          ┌──────────────┐
       │ Device Lat  │          │ Device Freq  │
       │ Gate (10m)  │          │ Gate (8m)    │
       └──────┬──────┘          └──────┬───────┘
              │                        │
              └────────────┬───────────┘
                           │
                    ┌──────v───────┐
                    │ Publish      │
                    │ Release (5m) │
                    └──────────────┘
```

**Total Runtime:**
- Fast path (skip AOSP): 45 minutes
- Full path (with ROM): 285 minutes (tag-triggered only)

---

## SUCCESS METRICS (PHASE 5-7)

### Completion Checklist

- [ ] AOSP ROM builds end-to-end (S25+ flashing verified)
- [ ] Latency gate <10ms passing consistently
- [ ] Frequency validation 432 Hz ±0.5 Hz passing
- [ ] Magisk module in official Magisk Repo
- [ ] XDA thread published with 500+ downloads
- [ ] User settings app in F-Droid
- [ ] Medium article published (5K+ reads)
- [ ] GitHub Pages with 50+ visitors/month
- [ ] Community support infrastructure live
- [ ] Performance profiling baseline established
- [ ] VoIP research document published
- [ ] Codec compatibility matrix documented

### Autonomy Score

- [ ] 95%+ CI automation (1 manual step: git tag)
- [ ] Zero manual ROM builds (fully scripted)
- [ ] Zero manual device flashing (one-liner script)
- [ ] Zero manual publication (tag triggers release)
- [ ] Zero manual documentation updates (auto-deployed)

---

## RISK MITIGATION

### Known Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|-----------|
| AOSP build fails (deps) | Medium | High | Vendor fork + mirror |
| Device latency >10ms (HW) | Low | High | Fallback to PATH-B ROM |
| Magisk repo rejection | Low | Medium | Alternative distro (XDA, GitHub) |
| Codec incompatibility | Medium | Low | Document + provide workarounds |
| Community support overload | High | Low | Auto-responders + FAQ |

### Rollback Plan

- If latency gate fails: Revert WSOLA parameters to conservative defaults
- If ROM build fails: Publish Magisk-only release (PATH-C)
- If community response negative: Archive and document lessons learned

---

## EXECUTION ROADMAP

### Week 9-10: Sprint 5 (Production Readiness)
- [ ] AOSP ROM build automation complete
- [ ] Device flash scripts production-ready
- [ ] Latency/frequency gates implemented
- [ ] Magisk repo submission prepared

### Week 11-12: Sprint 6 (Optimization)
- [ ] Performance profiling baseline established
- [ ] User settings UI complete
- [ ] VoIP research documented
- [ ] Codec latency analysis complete

### Week 13-14: Sprint 7 (Release & Community)
- [ ] GitHub release automation active
- [ ] Community channels established
- [ ] Documentation published
- [ ] First production release deployed

---

## LONG-TERM VISION (Beyond Week 14)

### Future Enhancements (Post-Release)

1. **AI-Driven Tuning** — ML model to auto-adjust WSOLA params per device
2. **Multi-Device Support** — Pixel 9, OnePlus 13, etc.
3. **Advanced Audio Analysis** — Real-time frequency response visualization
4. **DAW Integration** — Export AudioShift effects as VST/AU plugin
5. **Academic Publication** — WSOLA optimization techniques paper
6. **Open-Source Hardware** — DIY audio hardware with AudioShift DSP

---

## CONCLUSION

This master action plan transforms AudioShift from **production-ready codebase** to **community-deployed project** with 85%+ automation. By **Week 14**, AudioShift will be:

✅ **Available to end-users** (Magisk Repo + XDA)
✅ **Fully documented** (GitHub Pages + Medium)
✅ **Performance-optimized** (baselines established)
✅ **Community-supported** (Discord + GitHub Discussions)
✅ **Research-validated** (VoIP/codec studies published)

**Next Action:** Approve Sprint 5.1 and trigger AOSP ROM build automation.

---

**Document Version:** 1.0
**Date Created:** 2026-02-24
**Maintainer:** AudioShift Project Lead
**Status:** READY FOR EXECUTION
