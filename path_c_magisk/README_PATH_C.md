# PATH-C: Magisk Module Implementation

## Overview

PATH-C implements real-time 432 Hz audio conversion via Magisk module that hooks into Android's audio framework at runtime.

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

[See testing procedures in docs/DEVELOPMENT_GUIDE.md](../docs/DEVELOPMENT_GUIDE.md)

## Known Limitations

- Cannot intercept all VoIP call types
- Some apps may bypass audio system

## Discoveries

See [DISCOVERIES_PATH_C.md](DISCOVERIES_PATH_C.md) for architectural insights.
