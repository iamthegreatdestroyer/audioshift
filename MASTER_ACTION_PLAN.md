# AudioShift — Next Steps Master Action Plan

> **Generated:** 2025-07-10  
> **Philosophy:** Maximize autonomy and automation at every stage — humans approve, machines execute.  
> **Linked to:** `EXECUTIVE_SUMMARY.md` § 4 (Incomplete Work), § 5 (Phase Status)

---

## Execution Principles

1. **Automate before you manually repeat** — if a task will be done more than once, script it first.
2. **CI is the source of truth** — no change is considered "done" until it passes automated gates.
3. **Fail fast, fail loud** — every automation must have observable success/failure states.
4. **Phases are sequential within each track** — but PATH-B and PATH-C tracks are parallel.
5. **Document discoveries as they happen** — `DISCOVERY_LOG.md` should update with each task.

---

## Workstream Overview

```
Track 0: INFRASTRUCTURE (unblock everything else — do this first)
Track 1: PATH-C VALIDATION (highest ROI — code is complete, needs device testing)
Track 2: PATH-B COMPLETION (complex, long-tail — parallel with Track 1)
Track 3: TEST AUTOMATION (CI/CD, device farms, regression)
Track 4: DOCUMENTATION & COMMUNITY (ongoing, parallelizable)
```

---

## TRACK 0 — Infrastructure (Do These First, Days 1–2)

These are blockers. Nothing in Tracks 1–4 can be fully automated without these.

### 0.1 Wire GitHub Actions CI ⚡ BLOCKER

**Priority:** P0 — CRITICAL  
**Effort:** 5 minutes  
**Automation Benefit:** All future pushes trigger automated build + test

```bash
# Execute immediately:
cp s:\audioshift\ci_cd\build_and_test.yml s:\audioshift\.github\workflows\build_and_test.yml
```

**Verification:** Push any file; confirm workflow appears in GitHub → Actions tab with green status.

**Expand the workflow to include:**

- Trigger on `push` to `main` and `develop`, all `pull_request`
- Add matrix build: `{os: [ubuntu-22.04], ndk: [26.3.11579264]}`
- Cache: `~/.gradle/caches`, NDK, CMake build dirs
- Upload test results as artifacts

### 0.2 Fix `.gitignore`

**Priority:** P0  
**Effort:** 10 minutes  
**Automation Benefit:** Prevents repo pollution on every developer machine

Add to `.gitignore` (create if missing):

```gitignore
# VS Code local history
.history/

# CMake build output
shared/dsp/build_host/
build/
cmake-build-*/

# Android build output
path_b_rom/android/out/
*.so
*.a

# Python caches
__pycache__/
*.pyc
.pytest_cache/

# OS artifacts
.DS_Store
Thumbs.db
```

Then remove already-tracked `.history/` from git:

```bash
git rm -r --cached .history/
git commit -m "chore: add .gitignore, remove .history/ from tracking"
```

### 0.3 Create `.github/` Standard Templates

**Priority:** P1  
**Effort:** 1 hour  
**Automation Benefit:** Enforces structured contributions; enables automated labeling

Create these files:

- `.github/ISSUE_TEMPLATE/bug_report.md`
- `.github/ISSUE_TEMPLATE/device_compatibility.md`
- `.github/ISSUE_TEMPLATE/feature_request.md`
- `.github/PULL_REQUEST_TEMPLATE.md`
- `.github/CODEOWNERS` — assign ownership of `path_c_magisk/`, `shared/dsp/`, etc.
- `.github/dependabot.yml` — auto-update GitHub Actions versions

### 0.4 Update Living Documents

**Priority:** P1  
**Effort:** 30 minutes

| Document           | Action                                                                                                     |
| ------------------ | ---------------------------------------------------------------------------------------------------------- |
| `README.md`        | Mark Phases 2–3 ✅; update "current phase" to Phase 4                                                      |
| `CHANGELOG.md`     | Add entries for all Phase 2–3 work (SoundTouch DSP, hook library, Magisk module, test suite, CI, examples) |
| `DISCOVERY_LOG.md` | Add Week 2 (PATH-B skeleton), Week 3 (PATH-C native hook), Week 4 (test suite + CI) entries                |

---

## TRACK 1 — PATH-C On-Device Validation (Days 3–14)

PATH-C code is complete. The only remaining work is running it on hardware.

### 1.1 Build the Magisk Module

**Effort:** 2–4 hours  
**Automation:** Build script exists (`path_c_magisk/build_scripts/`) — flesh it out

```bash
# In build_scripts/build_module.sh — automate the following steps:
# 1. NDK cross-compile:
${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/bin/clang++ \
  --target=aarch64-linux-android35 \
  -std=c++17 \
  -shared -fPIC \
  -o libAudioShift432Effect.so \
  path_c_magisk/native/audioshift_hook.cpp \
  -I shared/dsp/include \
  -L shared/dsp/build/arm64-v8a -lSoundTouch

# 2. Copy .so into module:
cp libAudioShift432Effect.so path_c_magisk/module/system/lib64/

# 3. Package zip:
cd path_c_magisk/module && zip -r ../../audioshift432-v0.1.zip .
```

**Deliverable:** `audioshift432-v0.1.zip` — installable via MMGR/Magisk app

### 1.2 Device Testbed Setup (Automated)

**Hardware required:** Galaxy S25+ with Magisk root  
**Effort:** 4 hours one-time setup

Create `scripts/setup_device_testbed.sh`:

```bash
#!/usr/bin/env bash
# Automate device testbed setup
set -euo pipefail

# Verify ADB connection
adb devices | grep -v "List" | grep "device" || { echo "No device found"; exit 1; }

# Verify Magisk installed
adb shell "which magisk" || { echo "Magisk not found"; exit 1; }

# Push verification tools
adb push path_c_magisk/tools/verify_432hz.py /data/local/tmp/
adb push path_c_magisk/tools/verify_432hz.sh /data/local/tmp/
adb shell chmod +x /data/local/tmp/verify_432hz.sh

echo "Device testbed ready."
```

### 1.3 Automated Module Installation & Validation

Flesh out `tests/integration/test_432hz_device.sh` into a complete automated test:

```bash
#!/usr/bin/env bash
# Full integration test with pass/fail reporting
DEVICE_ID="${1:-$(adb devices | grep device | head -1 | cut -f1)}"
MODULE_ZIP="audioshift432-v0.1.zip"

# 1. Push module
adb -s "$DEVICE_ID" push "$MODULE_ZIP" /sdcard/

# 2. Install via Magisk CLI
adb -s "$DEVICE_ID" shell "magisk --install-module /sdcard/$MODULE_ZIP"

# 3. Reboot and wait
adb -s "$DEVICE_ID" reboot
adb -s "$DEVICE_ID" wait-for-device
sleep 30  # allow boot + Magisk initialization

# 4. Run frequency verification
RESULT=$(adb -s "$DEVICE_ID" shell "python3 /data/local/tmp/verify_432hz.py 2>&1")

# 5. Assert 432 Hz detected
echo "$RESULT" | grep -q "432" && {
  echo "✅ PASS: 432 Hz confirmed on device"
  exit 0
} || {
  echo "❌ FAIL: 432 Hz NOT detected"
  echo "Output: $RESULT"
  exit 1
}
```

### 1.4 Latency Benchmarking (Automated)

Flesh out `tests/performance/benchmark_latency.sh`:

```bash
#!/usr/bin/env bash
# Automated latency measurement
# Inject known tone → capture processed output → compute latency
SAMPLE_RATE=48000
DURATION_MS=500

# Play test tone (440 Hz) through AudioTrack, capture through AudioRecord
# Measure delta between input and output timestamps
# Report: min/mean/max/p99 latency in milliseconds

adb shell "am instrument -w \
  -e class com.audioshift.test.LatencyTest \
  com.audioshift.test/androidx.test.runner.AndroidJUnitRunner"
```

**Targets (from docs):**

- Processing latency: < 10 ms
- CPU overhead: < 5% on Snapdragon 8 Elite
- Memory: < 4 MB working set

### 1.5 Automated Regression Suite

Add `scripts/run_device_regression.sh`:

```bash
#!/usr/bin/env bash
# Run full regression: unit + integration + performance + verify
set -e
bash scripts/run_all_tests.sh                     # host unit tests
bash tests/integration/test_432hz_device.sh       # device integration
bash tests/performance/benchmark_latency.sh       # latency benchmark
python3 path_c_magisk/tools/verify_432hz.py       # frequency verification
echo "✅ All regression tests passed"
```

**Integrate into CI** as a conditional job triggered only when `adb` runner is available (self-hosted runner).

---

## TRACK 2 — PATH-B Custom ROM Completion (Weeks 2–8)

PATH-B is the long-tail. It requires significant infrastructure investment but provides the deepest system integration.

### 2.1 Set Up AOSP Build Environment (Automated)

**Effort:** 1–2 days (mostly download time — ~200 GB)

Automate with `scripts/setup_aosp_environment.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

AOSP_DIR="${AOSP_DIR:-$HOME/aosp}"
ANDROID_VERSION="android-14.0.0_r50"  # API 34 baseline for S25+

# Install dependencies
sudo apt-get install -y git-core gnupg flex bison build-essential zip curl \
  zlib1g-dev libc6-dev-i386 lib32ncurses5-dev x11proto-core-dev \
  libx11-dev lib32z1-dev libgl1-mesa-dev libxml2-utils xsltproc unzip

# Install repo tool
mkdir -p "$HOME/bin"
curl https://storage.googleapis.com/git-repo-downloads/repo > "$HOME/bin/repo"
chmod a+x "$HOME/bin/repo"

# Initialize AOSP repo
mkdir -p "$AOSP_DIR"
cd "$AOSP_DIR"
repo init -u https://android.googlesource.com/platform/manifest -b "$ANDROID_VERSION"
repo sync -j$(nproc) --no-clone-bundle --no-tags

echo "✅ AOSP environment ready at $AOSP_DIR"
```

### 2.2 Populate Missing PATH-B Components

| Task                                         | Action                                                           | Effort   |
| -------------------------------------------- | ---------------------------------------------------------------- | -------- |
| `path_b_rom/kernel/`                         | Add Galaxy S25+ kernel defconfig + audio DSP patch               | 1–2 days |
| `path_b_rom/device_configs/`                 | Add `audio_policy_configuration.xml`, `mixer_paths.xml` for S25+ | 4 hours  |
| `path_b_rom/android/build/`                  | Add `repo_manifest.xml` or `local_manifests/` for AOSP overlay   | 2 hours  |
| `path_b_rom/android/device/samsung/s25plus/` | Add device tree (clone from LineageOS s25+ if available)         | 1 day    |

### 2.3 AOSP Patch Automation

Create `path_b_rom/build_scripts/apply_patches.sh`:

```bash
#!/usr/bin/env bash
# Apply AudioShift patches to AOSP checkout
AOSP_DIR="${1:?Usage: $0 <aosp_dir>}"

# Patch AudioFlinger to load AudioShift432Effect
cp path_b_rom/android/frameworks/av/services/audioflinger/AudioShift432Effect.{h,cpp} \
   "$AOSP_DIR/frameworks/av/services/audioflinger/"

cp path_b_rom/android/frameworks/av/services/audioflinger/Android.bp \
   "$AOSP_DIR/frameworks/av/services/audioflinger/Android.bp"
# Note: Use 'patch' rather than copy to merge with existing Android.bp

# Patch HAL
cp path_b_rom/android/hardware/libhardware/audio_effect_432hz.h \
   "$AOSP_DIR/hardware/libhardware/include/hardware/"

echo "✅ AudioShift patches applied to AOSP at $AOSP_DIR"
```

### 2.4 ROM Build Automation

Flesh out `path_b_rom/build_scripts/build_rom.sh`:

```bash
#!/usr/bin/env bash
AOSP_DIR="${AOSP_DIR:?Set AOSP_DIR}"
TARGET="aosp_s25plus-userdebug"

cd "$AOSP_DIR"
source build/envsetup.sh
lunch "$TARGET"
make -j$(nproc) 2>&1 | tee build.log

echo "Build complete. Output: $AOSP_DIR/out/target/product/s25plus/"
```

### 2.5 Verify PATH-B Integration

After ROM is built and flashed:

```bash
# Verify effect registered in AOSP
adb shell "dumpsys media.audio_flinger | grep audioshift"

# Run frequency verification (same tool as PATH-C)
adb shell "python3 /data/local/tmp/verify_432hz.py"
```

---

## TRACK 3 — Test Automation & CI Expansion (Weeks 1–4, Parallel)

### 3.1 Self-Hosted Runner for Device Tests

**Goal:** Run on-device tests automatically on every PR

Set up a GitHub Actions self-hosted runner on the dev machine with ADB access:

```bash
# On dev machine:
mkdir actions-runner && cd actions-runner
curl -O -L https://github.com/actions/runner/releases/download/v2.x.x/actions-runner-linux-x64-2.x.x.tar.gz
tar xzf actions-runner-linux-x64-2.x.x.tar.gz
./config.sh --url https://github.com/iamthegreatdestroyer/audioshift --token <TOKEN>
./svc.sh install && ./svc.sh start
```

Add to `.github/workflows/build_and_test.yml`:

```yaml
device-test:
  needs: android-build
  runs-on: self-hosted
  if: github.ref == 'refs/heads/main'
  steps:
    - uses: actions/checkout@v4
    - name: Download module artifact
      uses: actions/download-artifact@v4
      with:
        name: audioshift432-module
    - name: Run integration tests
      run: bash tests/integration/test_432hz_device.sh
    - name: Run performance benchmarks
      run: bash tests/performance/benchmark_latency.sh
```

### 3.2 Host Unit Test CI (Fix the Wiring)

After wiring `build_and_test.yml` to `.github/workflows/`, verify each job passes:

```yaml
# Job 1: build
- name: Configure CMake
  run: cmake -S shared -B build -DCMAKE_BUILD_TYPE=Debug
- name: Build
  run: cmake --build build

# Job 2: unit-test
- name: Run unit tests
  run: cd build && ctest --output-on-failure --timeout 120

# Job 3: lint
- name: Run clang-tidy
  run: find path_c_magisk/native shared/dsp/src -name "*.cpp" | xargs clang-tidy

# Job 4: android-build
- name: NDK cross-compile
  run: |
    cmake -S path_c_magisk/native -B build-android \
      -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
      -DANDROID_ABI=arm64-v8a \
      -DANDROID_PLATFORM=android-35
    cmake --build build-android

# Job 5: integration-test (self-hosted)
- name: Device integration test
  run: bash tests/integration/test_432hz_device.sh
```

### 3.3 Code Coverage Reporting

Add to CI:

```yaml
- name: Run tests with coverage
  run: |
    cmake -S shared -B build-cov \
      -DCMAKE_BUILD_TYPE=Debug \
      -DCODE_COVERAGE=ON
    cmake --build build-cov
    cd build-cov && ctest
    lcov --capture --directory . --output-file coverage.info
    lcov --remove coverage.info '/usr/*' --output-file coverage.info

- name: Upload to Codecov
  uses: codecov/codecov-action@v4
  with:
    files: build-cov/coverage.info
```

### 3.4 Populate `research/` with Automated Collection

Create `scripts/collect_research.sh`:

```bash
#!/usr/bin/env bash
# Automated Android audio internals collection
mkdir -p research

# Pull Android audio framework source snippets
curl -sL "https://android.googlesource.com/platform/frameworks/av/+/refs/heads/main/media/libaudioclient/AudioEffect.cpp?format=TEXT" \
  | base64 -d > research/upstream_AudioEffect.cpp

# Pull SoundTouch algorithm documentation
curl -sL "https://www.surina.net/soundtouch/SoundTouch-algorithm.pdf" \
  -o research/SoundTouch-algorithm.pdf 2>/dev/null || true

# Document pitch math
cat > research/pitch_conversion_math.md << 'EOF'
# 432 Hz Conversion Mathematics

## Ratio
432 / 440 = 0.981818̄ (repeating)

## In Semitones
semitones = 12 × log₂(432/440) = -0.3164 semitones

## In Cents
cents = 1200 × log₂(432/440) = -31.766 cents

## SoundTouch API
soundtouch.setPitchSemiTones(-0.3164f);
// or equivalently:
soundtouch.setRateChange(-1.8182f);  // percent change
EOF

echo "✅ research/ populated"
```

---

## TRACK 4 — Documentation & Community (Weeks 2–6, Parallel)

### 4.1 Automated Documentation Generation

**Goal:** API docs generated from source on every push

Add Doxygen to CI:

```yaml
- name: Generate API docs
  run: |
    doxygen Doxyfile

- name: Deploy to GitHub Pages
  uses: peaceiris/actions-gh-pages@v4
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
    publish_dir: ./docs/html
```

Create `Doxyfile` at repo root with:

- `INPUT = path_c_magisk/native shared/dsp/include shared/audio_testing/src`
- `OUTPUT_DIRECTORY = docs/generated`
- `GENERATE_HTML = YES`
- `EXTRACT_ALL = YES`

### 4.2 Automated DISCOVERY_LOG Updates

Create `scripts/update_discovery_log.sh` — template for adding weekly entries:

```bash
#!/usr/bin/env bash
WEEK=$(date +%Y-W%V)
SECTION="## Week: $WEEK"

grep -q "$SECTION" DISCOVERY_LOG.md || cat >> DISCOVERY_LOG.md << EOF

$SECTION

### What I Discovered
-

### What Surprised Me
-

### Decisions Made
-

### Questions Generated
-

EOF

echo "Discovery log entry created for $WEEK"
```

### 4.3 CHANGELOG Automation

Add `standard-version` or `git-cliff` to automate changelog from conventional commits:

```bash
npm install -g git-cliff

# Add to CI:
git-cliff --output CHANGELOG.md
```

Configure `.cliff.toml` to extract `feat:`, `fix:`, `chore:`, `docs:` entries automatically.

### 4.4 Community Publication Checklist

When PATH-C is device-validated:

- [ ] XDA Developers post — template: `docs/XDA_POST_TEMPLATE.md` (create this)
- [ ] GitHub Release v1.0.0 — automated via Actions:
  ```yaml
  - name: Create Release
    uses: softprops/action-gh-release@v2
    if: startsWith(github.ref, 'refs/tags/')
    with:
      files: audioshift432-*.zip
  ```
- [ ] Magisk Modules repo — submit PR to official Magisk Modules Alt repo
- [ ] F-Droid — if companion app is built (future)

### 4.5 GitHub Pages Documentation Site

Structure:

```
docs/
├── index.md          → Landing page
├── getting-started/  → GETTING_STARTED.md
├── architecture/     → ARCHITECTURE.md + diagrams
├── api/              → Generated from Doxygen
└── contributing/     → DEVELOPMENT_GUIDE.md
```

Enable in GitHub repo → Settings → Pages → Source: GitHub Actions.

---

## Priority Matrix

| Task                        | Priority | Effort   | Automation Value | Track |
| --------------------------- | -------- | -------- | ---------------- | ----- |
| Wire `.github/workflows/`   | 🔴 P0    | 5 min    | ⭐⭐⭐⭐⭐       | 0     |
| Fix `.gitignore`            | 🔴 P0    | 10 min   | ⭐⭐⭐⭐         | 0     |
| Update README/CHANGELOG     | 🟡 P1    | 30 min   | ⭐⭐⭐           | 0     |
| Build PATH-C `.so`          | 🔴 P0    | 2–4 hr   | ⭐⭐⭐⭐         | 1     |
| Device testbed script       | 🟡 P1    | 4 hr     | ⭐⭐⭐⭐⭐       | 1     |
| Integration test script     | 🟡 P1    | 4 hr     | ⭐⭐⭐⭐⭐       | 1     |
| Self-hosted runner setup    | 🟡 P1    | 2 hr     | ⭐⭐⭐⭐⭐       | 3     |
| Code coverage in CI         | 🟢 P2    | 2 hr     | ⭐⭐⭐⭐         | 3     |
| Populate `research/`        | 🟢 P2    | 2 hr     | ⭐⭐             | 4     |
| AOSP build env setup        | 🟢 P2    | 1–2 days | ⭐⭐⭐⭐         | 2     |
| PATH-B kernel + device tree | 🔵 P3    | 3–5 days | ⭐⭐⭐           | 2     |
| Doxygen + GitHub Pages      | 🔵 P3    | 4 hr     | ⭐⭐⭐           | 4     |
| CHANGELOG automation        | 🔵 P3    | 2 hr     | ⭐⭐⭐⭐         | 4     |
| XDA / Magisk community post | 🔵 P3    | 4 hr     | ⭐⭐             | 4     |

---

## Weekly Sprint Template

### Sprint 1 (Days 1–7): Unblock + First Device Run

- [ ] 0.1 Wire GitHub Actions → verify green CI
- [ ] 0.2 Fix .gitignore + remove .history/
- [ ] 0.4 Update README + CHANGELOG
- [ ] 1.1 Build PATH-C .so (NDK cross-compile)
- [ ] 1.2 Device testbed setup script
- [ ] 1.3 Flash module → first device validation

**Definition of Done:** Green CI badge on `main`; module flashed; `verify_432hz.py` outputs 432 Hz confirmed.

### Sprint 2 (Days 8–14): Device Validation + CI Expansion

- [ ] 1.3 Full integration test automation
- [ ] 1.4 Latency benchmark — hit < 10 ms target
- [ ] 3.1 Self-hosted runner wired to CI
- [ ] 1.5 Regression suite running end-to-end

**Definition of Done:** PR gate: device tests pass before merge; latency target met; CI badge shows all 6 jobs green.

### Sprint 3 (Days 15–21): PATH-B Foundation + Docs

- [ ] 2.1 AOSP environment set up and synced
- [ ] 2.2 `device_configs/` and `android/build/` populated
- [ ] 4.1 Doxygen generation in CI
- [ ] 4.3 CHANGELOG automation (git-cliff)
- [ ] 3.4 Populate `research/`

**Definition of Done:** AOSP checkout synced; `apply_patches.sh` runs without error; API docs published to GitHub Pages.

### Sprint 4 (Days 22–28): PATH-B ROM Build Attempt

- [ ] 2.2 Kernel patches + device tree
- [ ] 2.3 `apply_patches.sh` verified against AOSP checkout
- [ ] 2.4 First ROM build attempt (expect failures — document them)
- [ ] 2.5 ROM flashed and validated (if build succeeds)

**Definition of Done:** Documented build log; at minimum the AudioShift `.so` compiles in AOSP context.

### Sprint 5+ (Days 29+): Community + Hardening

- [ ] 4.4 XDA + Magisk forum post (after device validation)
- [ ] 4.4 GitHub Release v1.0.0 (automated via Actions tag push)
- [ ] 4.5 GitHub Pages site live
- [ ] Conflict matrix: test with LSPosed, other popular Magisk modules
- [ ] Battery + thermal profiling

---

## Automation Architecture Diagram

```
Developer pushes code
         │
         ▼
┌─────────────────────────────────────────┐
│        GitHub Actions (Cloud)           │
│  Job 1: CMake build (ubuntu-22.04)      │
│  Job 2: Unit tests + coverage           │
│  Job 3: clang-tidy lint                 │
│  Job 4: NDK cross-compile → arm64-v8a  │
│  Job 5: Upload .so artifact             │
└──────────────────┬──────────────────────┘
                   │ (artifact download)
                   ▼
┌─────────────────────────────────────────┐
│    Self-Hosted Runner (Dev Machine)     │
│  Job 6: ADB push module to S25+         │
│  Job 7: Flash via Magisk CLI + reboot   │
│  Job 8: verify_432hz.py → assert 432   │
│  Job 9: benchmark_latency.sh → assert  │
│  Job 10: Upload test report artifact    │
└─────────────────────────────────────────┘
```

---

## Success Criteria

| Milestone          | KPI                                     | Target    |
| ------------------ | --------------------------------------- | --------- |
| CI Live            | GitHub Actions badge: passing           | Day 1     |
| PATH-C First Flash | `verify_432hz.py` → "432 Hz confirmed"  | Week 1    |
| Latency Target Met | `benchmark_latency.sh` → < 10 ms p50    | Week 2    |
| Full Automation    | PR gate: device tests required to merge | Week 2    |
| PATH-B ROM Build   | `build_rom.sh` produces flashable zip   | Month 2   |
| Community Release  | v1.0.0 GitHub Release + XDA post        | Month 2–3 |
| Documentation Live | GitHub Pages site → docs auto-generated | Month 1   |
