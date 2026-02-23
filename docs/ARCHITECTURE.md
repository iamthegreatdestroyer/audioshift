# AudioShift Architecture

## System Overview

### Audio Pipeline Hierarchy

```
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

## Integration Points

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

The audio conversion pipeline operates as follows:

1. **PCM Capture:** Raw audio stream from application
2. **Pitch Detection:** Identify current frequency characteristics
3. **Shift Algorithm:** Apply WSOLA-based pitch shift (-31.77 cents)
4. **Quality Preservation:** Maintain audio fidelity during conversion
5. **Output Encoding:** Re-encode for target codec/transport

## Performance Characteristics

| Metric | PATH-B | PATH-C |
|--------|--------|--------|
| Latency | <5ms | 10-15ms |
| CPU Load | 3-5% | 6-10% |
| Coverage | 100% | 90%+ |
| Installation | ROM flash | Magisk install |

## Device Specifics (Galaxy S25+)

- **Processor:** Snapdragon 8 Elite
- **Audio Codec:** WCD939x (Qualcomm)
- **Amplifier:** Cirrus Logic CX2092
- **Bluetooth:** Snapdragon Qualcomm
- **Sample Rate:** 48kHz default, 96kHz capable
