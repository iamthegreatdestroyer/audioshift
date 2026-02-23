# PATH-B AOSP Integration Guide

This document describes the manual edits required to integrate AudioShift into an AOSP checkout beyond what `build_rom.sh` copies automatically.

## Prerequisites

- AOSP source checked out with `repo init` and `repo sync`
- Android NDK r26+ installed
- CMake 3.22+
- Samsung Galaxy S25+ device with unlocked bootloader

## Manual Integration Steps

### Step 1: Edit frameworks/av/services/audioflinger/Android.bp

Add `libaudioshift432` to the `optional_shared_libs` list in the AudioFlinger module:

```bp
// In frameworks/av/services/audioflinger/Android.bp
cc_library {
    name: "libaudioflinger",
    ...
    optional_shared_libs: [
        "libaudioshift432",  // ADD THIS LINE
    ],
    ...
}
```

###Step 2: Edit frameworks/av/services/audioflinger/AudioFlinger.cpp

In the `AudioFlinger::AudioFlinger()` constructor, add code to load the AudioShift effect after other effects are loaded (approximately line 150-200):

```cpp
// In AudioFlinger::AudioFlinger()
// After other effect loading code:

// Load AudioShift 432Hz effect
int32_t status = load_effects_config();  // Ensure config is loaded first
if (status != 0) {
    ALOGW("Failed to load effects configuration");
}

ALOGI("AudioFlinger: AudioShift 432Hz effect loaded");
```

### Step 3: Merge audio_effects.xml

The AudioShift entry must be merged with your device's existing `audio_effects.xml`. The file is typically located at:

- `device/samsung/s25plus/audio_effects.xml` (or `/vendor/etc/audio_effects.xml` at runtime)

Merge the AudioShift `<effect>` entry into the existing effects list:

```xml
<effects>
    <!-- Existing effects -->
    <effect name="AudioShift432Hz"
            library="libaudioshift432"
            uuid="f22a9ce0-7a11-11ee-b962-0242ac120002"
            type="7b491460-8d4d-11e0-bd61-0002a5d5c51b"/>
</effects>
```

### Step 4: SELinux Policy

Add permissions to `device/samsung/s25plus/sepolicy/` (create if it doesn't exist):

Create `device_vendor_audioshift.te`:

```
# AudioShift 432Hz Effect SELinux Policy

type audioshift_vendor_file, vendor_file_type, file_type;

allow audioserver audioshift_vendor_file:file { read open getattr };
allow audioserver vendor_audioshift_lib:file { read open getattr map execute };
allow mediaserver audioshift_vendor_file:file { read open getattr };
```

### Step 5: Build DSP Library for arm64

Before building the ROM:

```bash
export AOSP_ROOT=/path/to/aosp
export NDK_PATH=/opt/android-ndk-r26

cd /s/audioshift/shared/dsp
mkdir build_arm64
cmake -B build_arm64 \
    -DCMAKE_TOOLCHAIN_FILE=$NDK_PATH/build/cmake/android.toolchain.cmake \
    -DANDROID_ABI=arm64-v8a \
    -DANDROID_PLATFORM=android-34 \
    -DCMAKE_BUILD_TYPE=Release

cmake --build build_arm64 --parallel $(nproc)
```

Then copy the built library:

```bash
mkdir -p $AOSP_ROOT/vendor/audioshift/lib64
cp build_arm64/libaudioshift_dsp.so $AOSP_ROOT/vendor/audioshift/lib64/
```

### Step 6: Build ROM

```bash
cd $AOSP_ROOT
source build/envsetup.sh
lunch aosp_s25plus-userdebug
m libaudioshift432 -j$(nproc)
m otapackage -j$(nproc)
```

## Verification

### On Build System

```bash
# Verify AudioShift effect was built
find $AOSP_ROOT/out -name "libaudioshift432*"

# Check effect is in audio_effects.xml
grep -r "AudioShift432Hz" $AOSP_ROOT/out/*/audio_effects.xml
```

### On Device (after flash)

```bash
# Check audio policy loaded correctly
adb shell dumpsys media.audio_flinger | grep -i audioshift

# Verify effect library is loaded
adb shell dumpsys media.audio_flinger | grep -i "libaudioshift"

# Check system properties
adb shell getprop audioshift.enabled
adb shell getprop audioshift.pitch_semitones

# Enable if needed
adb shell setprop audioshift.enabled 1
```

## Troubleshooting

### Build fails with "Cannot find libaudioshift432"

Ensure `vendor/audioshift/shared/dsp/` contains the DSP library source and `lib64/libaudioshift_dsp.so` exists in the build output directory.

### Audio Framework doesn't load effect

Check AudioFlinger logs:

```bash
adb logcat -s AudioFlinger | grep -i audioshift
```

Verify `audio_effects.xml` is correctly merged and contains the AudioShift entry.

### SELinux denials

Check for denials:

```bash
adb logcat | grep "avc: denied"
```

Add necessary `allow` rules to the SELinux policy file above.

## Next Steps

After successful build and flashing:

1. Reboot device
2. Run verification tool: `adb shell dumpsys media.audio_flinger | grep audioshift`
3. Play audio and verify 432 Hz tuning is applied
4. Use spectrum analyzer to measure output frequency
