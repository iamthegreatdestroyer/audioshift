# PATH-B: Custom Android ROM Implementation

## Overview

PATH-B implements real-time 432 Hz audio conversion at the Android OS level via modifications to AudioFlinger and audio HAL.

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

[See build instructions in docs/DEVELOPMENT_GUIDE.md](../docs/DEVELOPMENT_GUIDE.md)

## Performance Targets

- **Latency:** <5ms
- **CPU Load:** <5%
- **Coverage:** 100% of audio
- **Supported Codecs:** All (SBC, AAC, aptX, LDAC)

## Testing

[See testing procedures in docs/DEVELOPMENT_GUIDE.md](../docs/DEVELOPMENT_GUIDE.md)

## Known Limitations

(To be documented during development)

## Discoveries

See [DISCOVERIES_PATH_B.md](DISCOVERIES_PATH_B.md) for architectural insights.
