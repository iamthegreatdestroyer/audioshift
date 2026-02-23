# AudioShift CI/CD Pipeline

This directory contains GitHub Actions workflow definitions for the AudioShift project.

---

## Workflow: `build_and_test.yml`

### Jobs

| Job                 | Runner       | Purpose                                      | Estimated Time |
| ------------------- | ------------ | -------------------------------------------- | -------------- |
| `host_unit_tests`   | ubuntu-22.04 | Build & run GoogleTest C++ tests on host     | ~5 min         |
| `python_tests`      | ubuntu-22.04 | Run pytest FFT analysis tests                | ~2 min         |
| `clang_format`      | ubuntu-22.04 | Enforce Google C++ style via clang-format-15 | ~1 min         |
| `ndk_cross_compile` | ubuntu-22.04 | Cross-compile hook + DSP lib for ARM64       | ~15 min        |
| `build_summary`     | ubuntu-22.04 | Aggregate pass/fail status                   | <1 min         |

### Trigger Conditions

| Event                                                 | Jobs Run                              |
| ----------------------------------------------------- | ------------------------------------- |
| Push to `main`, `develop`, `feature/**`, `release/**` | All 5 jobs                            |
| Pull Request → `main` or `develop`                    | All 5 jobs                            |
| Draft Pull Request                                    | Jobs 1–4 (NDK skipped by default)     |
| Manual dispatch                                       | All 5 (NDK can be disabled via input) |

The `ndk_cross_compile` job is gated:

```yaml
if: |
  github.event_name != 'pull_request' ||
  github.event.pull_request.draft == false ||
  github.event.inputs.run_ndk_build == 'true'
```

To force it on a draft PR, use **Actions → workflow_dispatch → run_ndk_build = true**.

### Concurrency

Each branch gets at most one in-flight run. A new push cancels the previous:

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

---

## Test Coverage

### C++ Unit Tests (`host_unit_tests`)

Built with CMake + Ninja using GCC 12. GoogleTest v1.14.0 is fetched via `FetchContent`.

| Test Binary           | Tests | Coverage Area                                            |
| --------------------- | ----- | -------------------------------------------------------- |
| `test_pitch_ratio`    | 16    | `PITCH_RATIO_432_HZ`, `PITCH_SEMITONES_432_HZ` constants |
| `test_pcm_conversion` | 24    | PCM16/float math, saturation, roundtrip                  |
| `test_effect_context` | ~50   | ABI layout, UUIDs, descriptors, command enum             |

DSP library self-tests in `shared/dsp/` are also run.

### Python Tests (`python_tests`)

`pytest` with `numpy`. Coverage reported to `coverage.xml`.

| Test Class                   | Tests | Coverage Area                  |
| ---------------------------- | ----- | ------------------------------ |
| `TestFftFrequencyDetection`  | 11    | FFT peak detection, edge cases |
| `TestQuadraticInterpolation` | 3     | Sub-bin frequency refinement   |
| `TestConsensusDetection`     | 4     | Three-method median consensus  |
| `TestPitchShiftVerification` | 2     | 440→432 Hz shift verification  |
| `parametrize` sweep          | 7     | Frequencies 50–8000 Hz         |

### Formatting (`clang_format`)

All `.cpp`, `.h`, `.c`, `.cc` files outside `third_party/` and `build*/` directories
are checked against **Google C++ style**.

To auto-fix locally:

```bash
# Fix a single file
clang-format-15 --style=Google -i path/to/file.cpp

# Fix all project files
find . \
  -not -path '*/third_party/*' \
  -not -path '*/build*' \
  \( -name '*.cpp' -o -name '*.h' -o -name '*.c' \) \
  -exec clang-format-15 --style=Google -i {} \;
```

### NDK Cross-Compilation (`ndk_cross_compile`)

| Parameter   | Value                     |
| ----------- | ------------------------- |
| NDK Version | r26d (`26.3.11579264`)    |
| ABI         | `arm64-v8a`               |
| Android API | 35 (Android 15)           |
| STL         | `c++_shared`              |
| Toolchain   | `android.toolchain.cmake` |

Both the Magisk hook library (`libaudioshift_hook.so`) and DSP library are built.
The hook ELF is verified to be `ARM aarch64` via `file(1)`.

Built `.so` files are uploaded as CI artifacts (retained 7 days).

---

## Local Reproduction

Reproduce any CI job locally with these commands:

### Host Unit Tests

```bash
# Configure
cmake -B tests/unit/build_local \
  -S tests/unit \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DREPO_ROOT=$(pwd)

# Build
cmake --build tests/unit/build_local --parallel

# Run
cd tests/unit/build_local && ctest --output-on-failure
```

### Python Tests

```bash
pip install numpy pytest pytest-cov
pytest tests/unit/test_fft_analysis.py -v
```

### Format Check

```bash
find . -not -path '*/third_party/*' -not -path '*/build*' \
  \( -name '*.cpp' -o -name '*.h' \) \
  -exec clang-format-15 --dry-run --Werror --style=Google {} \;
```

### NDK Build

```bash
export NDK_HOME=$ANDROID_SDK_ROOT/ndk/26.3.11579264

cmake -B path_c_magisk/native/build_ndk \
  -S path_c_magisk/native \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_TOOLCHAIN_FILE=$NDK_HOME/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-35

cmake --build path_c_magisk/native/build_ndk --parallel
```

---

## Artifacts

| Artifact                   | Produced By                    | Retention |
| -------------------------- | ------------------------------ | --------- |
| `ctest-output-<run_id>`    | `host_unit_tests` (on failure) | 30 days   |
| `python-coverage-<run_id>` | `python_tests`                 | 30 days   |
| `arm64-libs-<run_id>`      | `ndk_cross_compile`            | 7 days    |

---

## Adding New Tests

### C++ Test

1. Create `tests/unit/test_<name>.cpp` using GoogleTest.
2. Add to `tests/unit/CMakeLists.txt`:
   ```cmake
   add_executable(test_<name> test_<name>.cpp)
   target_link_libraries(test_<name> GTest::gtest_main)
   gtest_discover_tests(test_<name>)
   ```
3. CI picks it up automatically — no workflow changes needed.

### Python Test

1. Create `tests/unit/test_<name>.py` using `pytest`.
2. CI runs `pytest tests/unit/` automatically.
