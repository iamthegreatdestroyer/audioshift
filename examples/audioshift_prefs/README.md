# AudioShift Settings Preferences App

**Phase 6 § Sprint 6.2**

User-facing Android preferences application for real-time control of AudioShift 432Hz effect.

## Overview

This is a standalone Android app that provides a polished UI for adjusting AudioShift parameters at runtime. Users can modify pitch, latency, and CPU parameters without restarting their device.

### Features

- ✅ **Enable/Disable Toggle** — Turn AudioShift effect on/off instantly
- ✅ **Pitch Adjustment** — Slider for ±100 cents shift (-100 to +100)
- ✅ **WSOLA Parameter Tuning** — Advanced controls for latency/quality tradeoff
  - Sequence length: 20-80ms
  - Seek window: 5-30ms
  - Overlap: 2-20ms
- ✅ **Live Performance Monitoring**
  - Latency readout (target: <15ms)
  - CPU usage gauge (target: <10%)
  - Output frequency display
- ✅ **Device Info**
  - Active audio device (Speaker/Headset/Bluetooth)
  - AudioShift version
  - Installation verification
- ✅ **Help & Troubleshooting**
  - Inline help text and tooltips
  - Installation verification
  - About screen

## Architecture

```
AudioShift Settings App
├── AndroidManifest.xml              Permissions, activities, services
├── build.gradle.kts                 Gradle build configuration
├── res/
│   ├── values/strings.xml           All UI text strings
│   ├── xml/preferences.xml          Preference UI hierarchy
│   └── layout/activity_preferences.xml
└── src/main/kotlin/com/audioshift/settings/
    ├── ui/
    │   ├── AudioShiftPreferencesActivity.kt   Main activity
    │   ├── PreferencesFragment.kt              Preferences UI
    │   └── AboutActivity.kt                     About screen
    ├── services/
    │   └── AudioShiftSettingsService.kt        Background monitoring
    └── receivers/
        └── AudioShiftBroadcastReceiver.kt      System audio events
```

## Components

### Activities

#### AudioShiftPreferencesActivity
- Main entry point
- Hosts PreferencesFragment
- Verifies AudioShift module installation
- Shows warning if module not detected

#### AboutActivity
- Version information
- Credits and licensing
- Repository link
- Troubleshooting guide

### Fragments

#### PreferencesFragment
- Implements `PreferenceFragmentCompat`
- Handles preference hierarchy
- Synchronizes changes to system properties
- Updates performance readouts in real-time

### Services

#### AudioShiftSettingsService (optional)
- Background service for continuous monitoring
- Publishes performance metrics
- Updates persistent notifications

### Receivers

#### AudioShiftBroadcastReceiver (optional)
- Detects audio device changes
- Updates UI on audio becoming noisy
- Handles boot completion

## Preferences & System Properties

Settings are stored in SharedPreferences and synchronized to Android system properties for persistence.

| SharedPreference Key | System Property | Type | Range | Default |
|---|---|---|---|---|
| `audioshift.enabled` | `audioshift.enabled` | bool | 0-1 | true |
| `audioshift.pitch_cents` | `audioshift.pitch_semitones` | int | -100 to +100 | -32 |
| `audioshift.wsola.sequence_ms` | `audioshift.wsola.sequence_ms` | int | 20-80 | 40 |
| `audioshift.wsola.seekwindow_ms` | `audioshift.wsola.seekwindow_ms` | int | 5-30 | 15 |
| `audioshift.wsola.overlap_ms` | `audioshift.wsola.overlap_ms` | int | 2-20 | 8 |

### Read-Only Properties (from device)

| Property | Source | Display |
|---|---|---|
| `audioshift.latency_ms` | Audio effect runtime | "Latency: 9.5ms" |
| `audioshift.cpu_percent` | Performance monitor | "CPU: 6.2%" |
| `audioshift.output_frequency` | FFT analysis | "Output: 432.1 Hz" |
| `audioshift.version` | Module metadata | "v2.0.0" |

## Building

### Prerequisites

- Android SDK 34 (API level 34)
- Android NDK r26 (optional, for native testing)
- Kotlin 1.9+
- Gradle 8+

### Compile

```bash
cd examples/audioshift_prefs

# Build debug APK
./gradlew assembleDebug

# Build release APK (requires keystore)
./gradlew assembleRelease

# Build for F-Droid (open source distribution)
./gradlew buildFDroid
```

### Output

APK files will be in: `build/outputs/apk/`

## Installation

### Option 1: Via Magisk Module

If AudioShift is installed as a Magisk module, this settings app can be bundled:

```bash
# Copy to module
cp -r examples/audioshift_prefs/build/outputs/apk/release/audioshift_prefs.apk \
  path_c_magisk/module/system/app/AudioShiftSettings/

# Module will auto-install on device
```

### Option 2: Via ADB

```bash
adb install build/outputs/apk/debug/audioshift_prefs.apk
```

### Option 3: Direct Installation

1. Transfer APK to device
2. Enable "Unknown sources" in Settings
3. Tap APK to install

## Usage

### Enable AudioShift

1. Open AudioShift Settings app
2. Toggle "Enable AudioShift" switch ON
3. Effect activates immediately on all audio

### Adjust Pitch

1. In "Pitch Adjustment" section
2. Slide "Pitch Shift" to desired value
3. Default: -32 cents (≈432 Hz)
4. Range: -100 to +100 cents

### Tune Performance

1. In "Audio Processing (Advanced)" section
2. Adjust WSOLA parameters:
   - **Sequence**: Higher = better quality but more latency
   - **Seek Window**: Higher = better quality but more processing
   - **Overlap**: Balance between latency and smoothness
3. Recommended: Keep defaults unless troubleshooting

### Monitor Performance

In "Performance Monitoring" section, observe:
- **Latency**: Should be <15ms (ideal <10ms)
- **CPU Usage**: Should be <10% (ideal <5%)
- **Output Frequency**: Should be ~432Hz

## Troubleshooting

### "AudioShift module not installed"

- Install via Magisk Manager on rooted device
- Ensure device is running Android 12+ (API 31+)
- Verify ARM64 architecture: `adb shell uname -m` → should output `aarch64`

### Settings not taking effect

1. Tap "Verify Installation"
2. Check Magisk logs: Settings > About > Magisk logs
3. Try disable/enable toggle
4. Restart audio playback

### Latency too high (>15ms)

1. Reduce WSOLA "Sequence" parameter (smaller window)
2. Close background audio apps
3. Check CPU usage gauge
4. Reduce audio bitrate if possible

### CPU usage too high (>10%)

1. Increase WSOLA "Sequence" parameter (trade quality for CPU)
2. Reduce "Seek Window" to lower search overhead
3. Close other CPU-intensive apps
4. Check for system notification spam

## Permissions

The app requests:

- `MODIFY_AUDIO_SETTINGS` — Required to change effect parameters
- `READ_PHONE_STATE` — Optional, for VoIP detection
- `PACKAGE_USAGE_STATS` — Optional, for CPU monitoring

All permissions are handled gracefully with informative error messages.

## Development

### Adding New Settings

1. Add string in `res/values/strings.xml`
2. Add `<Preference>` in `res/xml/preferences.xml`
3. Handle change in `AudioShiftPreferencesFragment.onSharedPreferenceChanged()`
4. Update system property via `setSystemProperty()`

### Adding Custom UI

For more complex controls (e.g., frequency response graph):

1. Create custom `Preference` subclass extending `androidx.preference.Preference`
2. Override `onCreateView()` to provide custom layout
3. Add to `preferences.xml` with custom attributes

## Distribution

### F-Droid

This app is F-Droid compatible:

```bash
# Check F-Droid requirements
./gradlew lint

# Build without proprietary libraries/services
./gradlew assembleRelease -Pflavors=fdroid
```

### Google Play Store

Requires:

- Google Play Developer account ($25 one-time)
- App signing keystore
- Privacy policy
- Screenshots and description

### GitHub Releases

```bash
# Automatic release via CI/CD
git tag v1.0.0
git push origin v1.0.0

# APK attached to GitHub Release automatically
```

## Performance Impact

When AudioShift Settings is installed but not actively used:

- **RAM**: ~50 MB (Java + resources)
- **Storage**: ~5 MB (APK size)
- **Battery**: <1% drain (only refreshes UI on screen)

## Roadmap

### v1.1 (Future)

- [ ] Frequency response visualization (chart)
- [ ] Real-time waveform display
- [ ] Preset configurations (Music, Voice, etc.)
- [ ] Settings backup/restore
- [ ] Widget for quick toggle

### v2.0 (Future)

- [ ] Multi-device support (custom per-device profiles)
- [ ] Bluetooth codec tuning
- [ ] A/B comparison mode
- [ ] Integration with VoIP apps
- [ ] Offline frequency analysis

## Testing

### Unit Tests

```bash
./gradlew testDebug

# Expected: All tests pass
```

### Integration Tests

```bash
# On connected device
./gradlew connectedAndroidTest
```

### Manual Testing Checklist

- [ ] Toggle enable/disable
- [ ] Adjust pitch slider
- [ ] Modify WSOLA parameters
- [ ] Verify installation
- [ ] Check performance readouts
- [ ] Test on device without AudioShift installed (show warning)
- [ ] Test on non-ARM64 device (show error)
- [ ] Test on Android <12 (show version warning)

## Contributing

To contribute improvements:

1. Fork repository
2. Create feature branch: `git checkout -b feature/my-improvement`
3. Make changes with tests
4. Submit pull request

## License

MIT Open Source License - See [LICENSE](../../LICENSE) for details

## Support

- **GitHub Issues**: https://github.com/iamthegreatdestroyer/audioshift/issues
- **XDA Forum**: https://forum.xda-developers.com/... (if published)
- **Email**: contact@audioshift.local (if applicable)

---

**Built with:**
- Kotlin + AndroidX
- Material Design 3
- SoundTouch WSOLA
- Android AudioFlinger HAL

**Version:** 1.0
**Last Updated:** 2026-02-25
