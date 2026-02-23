# AudioShift API Reference

## Core Classes

### Audio432HzConverter

Real-time audio pitch-shift to 432 Hz tuning frequency.

#### Constructor
```cpp
Audio432HzConverter(int sampleRate = 48000, int channels = 2);
```

#### Methods

**process()**
```cpp
int process(int16_t* buffer, int numSamples);
```
Process audio buffer to 432 Hz pitch.

**setSampleRate()**
```cpp
void setSampleRate(int sampleRate);
```
Set sample rate (may reset internal state).

**setPitchShiftSemitones()**
```cpp
void setPitchShiftSemitones(float semitones);
```
Set pitch shift amount in semitones (-0.53 for 432 Hz conversion).

**getLatencyMs()**
```cpp
float getLatencyMs() const;
```
Get estimated latency from input to output.

**getCpuUsagePercent()**
```cpp
float getCpuUsagePercent() const;
```
Get estimated CPU usage.

## Namespace

All classes and functions are in `audioshift::dsp` namespace.

## Threading

Classes are thread-safe for single-consumer usage. Multiple threads must synchronize access externally.

---

*(This document will be expanded with additional APIs as development progresses)*
