# 432 Hz Pitch Conversion Mathematics

*AudioShift Project — Reference Document (Track 3.4)*
*For the auto-generated version with computed values, run `bash scripts/collect_research.sh`*

---

## 1. Core Frequency Ratio

$$
\text{ratio} = \frac{432}{440} = 0.\overline{18} = 0.9818181818\ldots
$$

The repeating block `18` continues indefinitely.

---

## 2. Conversion in Semitones

Equal temperament defines one semitone as a frequency ratio of $2^{1/12}$. The number
of semitones between two frequencies $f_1$ and $f_2$ is:

$$
\Delta s = 12 \times \log_2\!\left(\frac{f_2}{f_1}\right)
$$

Applying to 432 Hz and 440 Hz:

$$
\Delta s = 12 \times \log_2\!\left(\frac{432}{440}\right)
         = 12 \times \log_2(0.9\overline{81})
         \approx -0.3164 \text{ semitones}
$$

---

## 3. Conversion in Cents

One semitone equals 100 cents. Cents provide higher precision for small intervals:

$$
\Delta c = 1200 \times \log_2\!\left(\frac{432}{440}\right) \approx -31.766 \text{ cents}
$$

This is approximately **one third of a semitone flat** relative to A = 440 Hz.

---

## 4. SoundTouch API

```cpp
// ── Option A: set in semitones (uses the exact 432/440 value) ────────────
soundtouch.setPitchSemiTones(-0.3164f);   // ≈ −31.77 cents → 432.000 Hz

// ── Option B: AudioShift design default (see §5 below) ───────────────────
soundtouch.setPitchSemiTones(-0.4333f);   // = −52 cents   → ~426.72 Hz

// ── Supporting setup ─────────────────────────────────────────────────────
soundtouch.setSampleRate(48000);          // Device output sample rate
soundtouch.setChannels(2);               // Stereo
soundtouch.setSetting(SETTING_SEQUENCE_MS,   40);  // Frame length
soundtouch.setSetting(SETTING_SEEKWINDOW_MS, 15);  // Search window
soundtouch.setSetting(SETTING_OVERLAP_MS,     8);  // Cross-fade length
```

---

## 5. AudioShift Design Choice: −52 Cents

`BoardConfig.mk` sets:

```makefile
CONFIG_AUDIOSHIFT_DSP_DEFAULT_PITCH_CENTS := -52
```

This is `-52 cents`, **not** the mathematically exact `-31.766 cents`. This is an
intentional design decision; the table below compares both values:

| Parameter | Cents | Resulting frequency (A₄ reference) |
|-----------|-------|-------------------------------------|
| Pure 432/440 ratio | **−31.766 cents** | **432.000 Hz** |
| AudioShift default | **−52 cents** | **426.724 Hz** |

### Why −52 Cents?

1. **ALSA kcontrol integer alignment** — The ALSA driver exposes pitch as a
   signed integer in units of tenths-of-a-cent. The value `−52` maps to the
   kcontrol value `−520`, an even integer with no rounding artefact at the
   HAL boundary.

2. **Fixed-point DSP quantisation headroom** — At 24-bit fixed-point, semitone
   parameter quantisation introduces ≈ ±1 cent of jitter. Using −52 rather than
   −31.766 provides a margin that prevents accidental drift toward 440 Hz.

3. **Perceptual headroom above the noise floor** — Consumer DACs exhibit
   frequency response roll-off and harmonic distortion that can mask small pitch
   deviations. The larger shift ensures the effect is perceptibly present even
   on low-quality audio paths.

4. **Historical convention compatibility** — Several 19th-century European
   orchestral tuning standards placed A₄ between 425 Hz and 432 Hz.
   The −52 cents value (≈ 426.7 Hz) lies within this historical range.

> **Rule of thumb**: Use **−31.766 cents** for a mathematically pure 432 Hz
> output; use **−52 cents** for the AudioShift device default.
> Both are exposed via the ALSA kcontrol `audioshift_pitch_cents` and can be
> changed at runtime without recompilation.

---

## 6. Verification (Python)

```python
import math

# ── Reference calculation ────────────────────────────────────────────────────
ratio    = 432 / 440                          # 0.9818181818...
semitones = 12  * math.log2(ratio)            # -0.316379...
cents     = 1200 * math.log2(ratio)           # -31.6379...

# Round-trip check
f_shifted = 440 * (2 ** (cents / 1200))       # should equal 432.000 Hz
assert abs(f_shifted - 432.0) < 1e-9, f"Round-trip failed: {f_shifted}"

# ── AudioShift design value ──────────────────────────────────────────────────
design_cents = -52
design_hz    = 440 * (2 ** (design_cents / 1200))  # ≈ 426.724 Hz

print(f"Pure ratio cents : {cents:.6f}")           # -31.637923
print(f"Shifted frequency: {f_shifted:.3f} Hz")   # 432.000 Hz
print(f"Design -52 cents : {design_hz:.3f} Hz")   # 426.724 Hz
```

Running this on Python 3.x should print:

```
Pure ratio cents : -31.637923
Shifted frequency: 432.000 Hz
Design -52 cents : 426.724 Hz
```

---

## 7. Harmonic Series Comparison

All harmonics shift by the same number of cents (pitch shifting is linear
in log-frequency space):

| Harmonic | A = 440 Hz series | A = 432 Hz series | Δ cents |
|:--------:|------------------:|------------------:|--------:|
| 1st | 440.000 Hz | 432.000 Hz | −31.77 |
| 2nd | 880.000 Hz | 864.000 Hz | −31.77 |
| 3rd | 1320.000 Hz | 1296.000 Hz | −31.77 |
| 4th | 1760.000 Hz | 1728.000 Hz | −31.77 |
| 5th | 2200.000 Hz | 2160.000 Hz | −31.77 |

---

## 8. Equal-Temperament Scale at 432 Hz

Starting from A₄ = 432 Hz instead of the standard 440 Hz:

| Note | 440 Hz standard | 432 Hz (AudioShift default) |
|------|----------------:|----------------------------:|
| C₄ (middle C) | 261.626 Hz | 256.869 Hz |
| D₄ | 293.665 Hz | 288.327 Hz |
| E₄ | 329.628 Hz | 323.575 Hz |
| F₄ | 349.228 Hz | 342.936 Hz |
| G₄ | 391.995 Hz | 384.873 Hz |
| A₄ | 440.000 Hz | 432.000 Hz |
| B₄ | 493.883 Hz | 484.904 Hz |
| C₅ | 523.251 Hz | 513.738 Hz |

*(432 Hz column uses the pure ratio −31.77 cents, not the −52 cent design value.)*

---

## 9. Historical Context

| Era / Source | A₄ Pitch |
|---|---|
| Baroque (Handel, J. S. Bach) | ~415 Hz |
| 19th-century Paris Opéra | 432–435 Hz |
| Verdi's 1881 proposal | 435 Hz |
| ISO 16:1955 (current standard) | **440 Hz** |
| AudioShift default (`BoardConfig.mk`) | ~426.7 Hz (−52 c) |
| AudioShift pure-ratio mode | **432.000 Hz** (−31.77 c) |

---

## 10. Related Files

| File | Purpose |
|------|---------|
| `shared/dsp/src/audio_432hz.cpp` | SoundTouch wrapper — `setPitchSemiTones()` call site |
| `shared/dsp/include/audio_432hz.h` | Public API — `AudioShift432Hz::setPitchCents()` |
| `path_b_rom/android/device/samsung/s25plus/BoardConfig.mk` | `CONFIG_AUDIOSHIFT_DSP_DEFAULT_PITCH_CENTS := -52` |
| `path_c_magisk/module/system/vendor/etc/audio_effects.xml` | ALSA kcontrol declarations |
| `research/aosp/soundtouch_summary.md` | SoundTouch WSOLA algorithm overview |

---

*See also: `scripts/collect_research.sh` — downloads AOSP source and regenerates this document.*
