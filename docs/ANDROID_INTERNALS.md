# Android Audio Architecture Deep-Dive

## AudioFlinger Architecture

AudioFlinger is the core audio mixer service in Android. It handles:
- Audio mixing from multiple sources
- Effect processing
- Codec interaction
- Bluetooth audio routing

## Audio HAL

The Hardware Abstraction Layer provides:
- Codec control interface
- Sample rate and format negotiation
- Hardware buffer management
- Device routing policy

## Audio Effects Framework

Android provides an effects framework for runtime DSP:
- Effects are loaded as shared libraries
- Registered in audio_effects.conf
- Can be applied per-stream or globally

## Signal Path for PATH-B (Custom ROM)

1. AudioFlinger receives audio from applications
2. Apply AudioShift pitch-shift effect
3. Mix with other sources
4. Route to codec/Bluetooth module

## Signal Path for PATH-C (Magisk Module)

1. Hook libaudioflinger library loading
2. Intercept audio processing calls
3. Apply pitch-shift to buffers
4. Return modified audio to caller

---

*(This document will be expanded with detailed architecture diagrams and implementation specifics)*
