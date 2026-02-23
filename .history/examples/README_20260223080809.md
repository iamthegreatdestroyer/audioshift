# AudioShift Examples

Runnable code examples demonstrating the AudioShift 432 Hz effect library.

---

## `basic_432hz_usage.cpp`

Demonstrates the complete lifecycle of an AudioShift effect instance:

1. `EffectCreate` — allocate and initialise the effect
2. `EFFECT_CMD_SET_CONFIG` — set sample rate (48 kHz) and stereo channel mask
3. `CMD_SET_ENABLED` — activate pitch shifting
4. `process` — feed 10 ms of 440 Hz PCM audio through the effect
5. `CMD_GET_LATENCY_MS` / `CMD_GET_CPU_USAGE` — read diagnostics
6. `EffectRelease` — clean up

### Expected Output

```
AudioShift 432 Hz — basic usage example
==========================================

[1/6] Creating AudioShift effect instance...
  OK — handle = 0x...

[2/6] Configuring effect (48 kHz, stereo)...
  OK

[3/6] Enabling pitch shift (440 Hz → 432 Hz)...
  OK — pitch shift active

[4/6] Processing 480 frames of 440 Hz audio...
  OK — RMS energy check passed (energy = ...)

[5/6] Querying diagnostics...
  Latency      : X.XX ms (budget: 20 ms)
  CPU usage    : X.X %
  Pitch ratio  : 0.981818  (432/440 = 0.981818)
  Pitch shift  : -0.3164 semitones

[6/6] Releasing effect...
  OK

==========================================
Example completed successfully.
```

---

## Building the Examples

### Prerequisites

| Tool         | Version | Purpose                |
| ------------ | ------- | ---------------------- |
| CMake        | ≥ 3.22  | Build system           |
| GCC or Clang | ≥ 10    | C++17 compiler         |
| Ninja        | any     | Fast builds (optional) |

The examples are **host-only** (Linux / macOS / WSL2). They use
`tests/unit/android_mock.h` to stub out Android headers so the code
compiles without the Android NDK.

### Quick Start

```bash
# From repo root
cmake -B examples/build \
      -S examples \
      -DCMAKE_BUILD_TYPE=RelWithDebInfo \
      -DREPO_ROOT=$(pwd)

cmake --build examples/build --parallel

./examples/build/basic_432hz_usage
```

### Debug Build (with AddressSanitizer)

```bash
cmake -B examples/build_debug \
      -S examples \
      -DCMAKE_BUILD_TYPE=Debug \
      -DREPO_ROOT=$(pwd)

cmake --build examples/build_debug --parallel
./examples/build_debug/basic_432hz_usage
```

---

## On-Device Usage (Android)

The example shows the same API that AudioFlinger uses internally.
On a real device with the Magisk module installed:

1. The module writes `libaudioshift_hook.so` to `/vendor/lib64/soundfx/`.
2. `audio_effects.xml` registers the effect UUID with AudioFlinger.
3. Any audio output session automatically goes through `process()`.

To force-test on device:

```bash
# Push test tone from host
adb shell "am start -a android.intent.action.VIEW \
           -d file:///sdcard/440hz_tone.wav \
           -t audio/wav"

# Check AudioFlinger logs for AudioShift activity
adb logcat -s AudioShift
```

### Logcat Markers

| Tag          | Level | Meaning                                |
| ------------ | ----- | -------------------------------------- |
| `AudioShift` | `I`   | Effect created / destroyed             |
| `AudioShift` | `D`   | Per-buffer pitch-shift stats           |
| `AudioShift` | `W`   | Latency budget exceeded                |
| `AudioShift` | `E`   | Fatal errors (bad config, malloc fail) |

---

## Architecture Notes

### Effect Handle Lifetime

```
EffectCreate()       — allocates AudioShiftContext on the heap
  │
  ├── process() ×N  — called in AudioFlinger's hot path (~every 10 ms)
  │
EffectRelease()      — destroys SoundTouch instance + frees context
```

### ABI Constraint

The first member of `AudioShiftContext` **must** be `effect_interface_s *itfe`.
This is mandated by the Android audio effect ABI: AudioFlinger casts the
`effect_handle_t` pointer to `effect_interface_s **` and dereferences it to
reach the `process` and `command` function pointers.

`test_effect_context.cpp` guards this with:

```cpp
static_assert(offsetof(HostAudioShiftContext, itfe) == 0,
              "itfe must be first — Android audio effect ABI");
```

### Pitch Ratio Derivation

```
ratio       = 432 / 440 = 0.9̄81̄8̄
semitones   = 12 × log₂(432 / 440) ≈ −0.3164 st
```

SoundTouch accepts semitone adjustment via `setPitchSemiTones()`.
The value is negative because 432 Hz is lower than 440 Hz.

---

## Adding New Examples

1. Create `examples/your_example.cpp`.
2. Add to `examples/CMakeLists.txt`:
   ```cmake
   add_executable(your_example your_example.cpp)
   target_include_directories(your_example PRIVATE
       ${ANDROID_MOCK_DIR} ${HOOK_INCLUDE_DIR} ${DSP_INCLUDE_DIR})
   target_link_libraries(your_example PRIVATE m)
   ```
3. Document it in this README under a new `##` heading.
