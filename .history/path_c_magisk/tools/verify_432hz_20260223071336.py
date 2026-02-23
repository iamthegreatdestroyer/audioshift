#!/usr/bin/env python3
"""
AudioShift 432 Hz Frequency Verification Tool

Analyzes an audio file (captured from device or direct) and verifies
that the dominant pitch has been shifted from 440 Hz to ≈432 Hz.

Usage:
    python3 verify_432hz.py --input captured.wav
    python3 verify_432hz.py --input captured.wav --expected 432 --tolerance 1.5
    python3 verify_432hz.py --input captured.wav --report report.json

Requirements:
    pip install numpy scipy soundfile

Optional (better pitch tracking):
    pip install librosa
"""

import argparse
import json
import math
import sys
from pathlib import Path


# ─── Constants ────────────────────────────────────────────────────────────────

EXPECTED_HZ_DEFAULT   = 432.0
INPUT_HZ_DEFAULT      = 440.0
TOLERANCE_HZ_DEFAULT  = 2.0
EXPECTED_SEMITONES    = 12 * math.log2(432.0 / 440.0)   # ≈ -0.3164
EXPECTED_RATIO        = 432.0 / 440.0                    # ≈ 0.9818


# ─── Helpers ─────────────────────────────────────────────────────────────────

def load_audio(path: str):
    """Load audio file, return (samples_float32, sample_rate)."""
    try:
        import soundfile as sf
        data, sr = sf.read(path, dtype="float32", always_2d=True)
        # Mix to mono for pitch analysis
        mono = data.mean(axis=1)
        return mono, sr
    except ImportError:
        pass

    # Fallback: scipy.io.wavfile
    try:
        from scipy.io import wavfile
        import numpy as np
        sr, data = wavfile.read(path)
        if data.ndim > 1:
            data = data.mean(axis=1)
        if data.dtype != "float32":
            data = data.astype("float32") / (2 ** 15)
        return data, sr
    except Exception as exc:
        print(f"[ERROR] Cannot load audio: {exc}", file=sys.stderr)
        print("  Install: pip install soundfile  OR  pip install scipy", file=sys.stderr)
        sys.exit(1)


def fft_peak_frequency(samples, sample_rate: int, window_sec: float = 2.0) -> dict:
    """
    Find the peak frequency in the first `window_sec` of audio via FFT.

    Returns a dict with peak_hz, magnitude, and the frequency bins.
    """
    import numpy as np

    n = min(int(window_sec * sample_rate), len(samples))
    chunk = samples[:n]

    # Apply Hann window to reduce spectral leakage
    window = np.hanning(n)
    windowed = chunk * window

    # Zero-pad to next power-of-2 for efficiency
    fft_size = 1 << (n - 1).bit_length()   # next power of 2
    spectrum = np.fft.rfft(windowed, n=fft_size)
    magnitudes = np.abs(spectrum)
    freqs = np.fft.rfftfreq(fft_size, d=1.0 / sample_rate)

    # Focus on 300–600 Hz band (where 432/440 sit)
    band_mask = (freqs >= 300) & (freqs <= 600)
    if not band_mask.any():
        peak_idx = np.argmax(magnitudes)
    else:
        band_mags = magnitudes.copy()
        band_mags[~band_mask] = 0
        peak_idx = np.argmax(band_mags)

    peak_hz = freqs[peak_idx]
    peak_mag = magnitudes[peak_idx]

    # Refine with quadratic interpolation (sub-bin accuracy)
    if 0 < peak_idx < len(magnitudes) - 1:
        alpha = magnitudes[peak_idx - 1]
        beta  = magnitudes[peak_idx]
        gamma = magnitudes[peak_idx + 1]
        p = 0.5 * (alpha - gamma) / (alpha - 2 * beta + gamma + 1e-12)
        bin_resolution = sample_rate / fft_size
        peak_hz = peak_hz + p * bin_resolution

    return {
        "peak_hz":        float(peak_hz),
        "magnitude":      float(peak_mag),
        "freqs":          freqs,
        "magnitudes":     magnitudes,
        "bin_resolution": float(sample_rate / fft_size),
    }


def harmonic_pitch_estimate(samples, sample_rate: int) -> float:
    """
    Estimate fundamental pitch using autocorrelation (HPS-like method).
    More robust than raw FFT peak for complex audio.
    """
    import numpy as np

    n = min(int(2.0 * sample_rate), len(samples))
    chunk = samples[:n]

    # Autocorrelation via FFT
    spec = np.fft.rfft(chunk, n=2 * n)
    acf = np.fft.irfft(spec * spec.conj())[:n]

    # Search in the 300–600 Hz range (lag range)
    lag_min = int(sample_rate / 600.0)
    lag_max = int(sample_rate / 300.0)
    if lag_min >= lag_max or lag_max >= len(acf):
        return 0.0

    peak_lag = np.argmax(acf[lag_min:lag_max]) + lag_min
    return float(sample_rate) / float(peak_lag) if peak_lag > 0 else 0.0


def detect_pitch_librosa(samples, sample_rate: int) -> float:
    """Use librosa's pyin for robust pitch detection (optional)."""
    try:
        import librosa
        import numpy as np
        f0, voiced_flag, voiced_prob = librosa.pyin(
            samples,
            fmin=librosa.note_to_hz("A4") * 0.8,   # ≈344 Hz
            fmax=librosa.note_to_hz("A4") * 1.2,   # ≈528 Hz
            sr=sample_rate,
        )
        voiced_f0 = f0[voiced_flag & (voiced_prob > 0.7)]
        if len(voiced_f0) > 0:
            return float(np.median(voiced_f0))
    except ImportError:
        pass
    return 0.0


def semitones_from_hz(measured: float, reference: float) -> float:
    if reference <= 0 or measured <= 0:
        return 0.0
    return 12.0 * math.log2(measured / reference)


def cents_from_hz(measured: float, reference: float) -> float:
    return semitones_from_hz(measured, reference) * 100.0


# ─── Main Analysis ────────────────────────────────────────────────────────────

def analyze(args) -> dict:
    import numpy as np

    print(f"[AudioShift] Loading: {args.input}")
    samples, sample_rate = load_audio(args.input)
    duration_s = len(samples) / sample_rate
    print(f"[AudioShift] Duration: {duration_s:.2f}s, SR: {sample_rate} Hz")

    results = {
        "file":          args.input,
        "sample_rate":   sample_rate,
        "duration_s":    round(duration_s, 3),
        "expected_hz":   args.expected,
        "tolerance_hz":  args.tolerance,
        "measurements":  {},
        "verdict":       "UNKNOWN",
    }

    # ── Method 1: FFT peak ────────────────────────────────────────────────────

    fft_result = fft_peak_frequency(samples, sample_rate)
    fft_hz = fft_result["peak_hz"]
    fft_semitones = semitones_from_hz(fft_hz, INPUT_HZ_DEFAULT)
    fft_cents = cents_from_hz(fft_hz, INPUT_HZ_DEFAULT)

    results["measurements"]["fft_peak"] = {
        "method":       "FFT windowed peak",
        "measured_hz":  round(fft_hz, 3),
        "semitones":    round(fft_semitones, 4),
        "cents":        round(fft_cents, 2),
        "bin_res_hz":   round(fft_result["bin_resolution"], 4),
    }

    print(f"\n  FFT Peak:         {fft_hz:.2f} Hz  ({fft_semitones:+.4f} semitones, {fft_cents:+.1f}¢)")

    # ── Method 2: Autocorrelation ─────────────────────────────────────────────

    acf_hz = harmonic_pitch_estimate(samples, sample_rate)
    if acf_hz > 0:
        acf_semitones = semitones_from_hz(acf_hz, INPUT_HZ_DEFAULT)
        acf_cents = cents_from_hz(acf_hz, INPUT_HZ_DEFAULT)
        results["measurements"]["autocorrelation"] = {
            "method":      "Autocorrelation (HPS)",
            "measured_hz": round(acf_hz, 3),
            "semitones":   round(acf_semitones, 4),
            "cents":       round(acf_cents, 2),
        }
        print(f"  Autocorrelation:  {acf_hz:.2f} Hz  ({acf_semitones:+.4f} semitones, {acf_cents:+.1f}¢)")

    # ── Method 3: librosa pyin (optional) ─────────────────────────────────────

    pyin_hz = detect_pitch_librosa(samples, sample_rate)
    if pyin_hz > 0:
        pyin_semitones = semitones_from_hz(pyin_hz, INPUT_HZ_DEFAULT)
        pyin_cents = cents_from_hz(pyin_hz, INPUT_HZ_DEFAULT)
        results["measurements"]["librosa_pyin"] = {
            "method":      "librosa pyin (probabilistic YIN)",
            "measured_hz": round(pyin_hz, 3),
            "semitones":   round(pyin_semitones, 4),
            "cents":       round(pyin_cents, 2),
        }
        print(f"  librosa pyin:     {pyin_hz:.2f} Hz  ({pyin_semitones:+.4f} semitones, {pyin_cents:+.1f}¢)")

    # ── Consensus and verdict ─────────────────────────────────────────────────

    measured_values = [v["measured_hz"] for v in results["measurements"].values() if v["measured_hz"] > 0]
    if not measured_values:
        results["verdict"] = "ERROR"
        results["error"] = "No pitch measurements succeeded"
        return results

    consensus_hz = float(np.median(measured_values))
    shift_hz     = abs(consensus_hz - INPUT_HZ_DEFAULT)
    error_hz     = abs(consensus_hz - args.expected)
    shift_semis  = semitones_from_hz(consensus_hz, INPUT_HZ_DEFAULT)
    shift_cents  = cents_from_hz(consensus_hz, INPUT_HZ_DEFAULT)

    results["consensus"] = {
        "measured_hz":      round(consensus_hz, 3),
        "shift_from_440hz": round(shift_hz, 3),
        "error_from_432hz": round(error_hz, 3),
        "semitones":        round(shift_semis, 4),
        "cents":            round(shift_cents, 2),
        "expected_semits":  round(EXPECTED_SEMITONES, 4),   # -0.3164
        "expected_ratio":   round(EXPECTED_RATIO, 6),       # 0.981818
    }

    passed = error_hz <= args.tolerance
    results["verdict"] = "PASS" if passed else "FAIL"

    print(f"\n  ─────────────────────────────────────────────────")
    print(f"  Consensus:        {consensus_hz:.2f} Hz")
    print(f"  Expected:         {args.expected:.2f} Hz")
    print(f"  Error:            {error_hz:.3f} Hz  (tolerance: ±{args.tolerance} Hz)")
    print(f"  Shift:            {shift_semis:+.4f} semitones  ({shift_cents:+.1f}¢)")
    print(f"  Expected shift:   {EXPECTED_SEMITONES:+.4f} semitones")
    print(f"  ─────────────────────────────────────────────────")

    if passed:
        print(f"\n  \033[1;32m✓ PASS — 432 Hz pitch shift verified\033[0m")
        print(f"         AudioShift is correctly downshifting by ~8 Hz")
    else:
        print(f"\n  \033[1;31m✗ FAIL — Measured {consensus_hz:.2f} Hz, expected {args.expected:.2f} ± {args.tolerance} Hz\033[0m")
        if consensus_hz > 438:
            print("         Pitch shift may not be active — check module installation")
        else:
            print("         Pitch shift active but ratio incorrect — check CMAKE config")

    # ── Spectrum plot (optional) ───────────────────────────────────────────────

    if args.plot:
        try:
            import matplotlib.pyplot as plt
            fft_data = fft_peak_frequency(samples, sample_rate, window_sec=min(duration_s, 3.0))
            freqs_plot = fft_data["freqs"]
            mags_plot  = fft_data["magnitudes"]

            # Focus on 300–600 Hz window
            mask = (freqs_plot >= 300) & (freqs_plot <= 600)
            plt.figure(figsize=(10, 4))
            plt.plot(freqs_plot[mask], 20 * np.log10(mags_plot[mask] + 1e-12))
            plt.axvline(INPUT_HZ_DEFAULT, color="r", linestyle="--", label="440 Hz (input)")
            plt.axvline(args.expected,    color="g", linestyle="--", label=f"{args.expected} Hz (expected)")
            plt.axvline(consensus_hz,     color="b", linestyle="-",  label=f"{consensus_hz:.1f} Hz (measured)")
            plt.xlabel("Frequency (Hz)")
            plt.ylabel("Magnitude (dB)")
            plt.title("AudioShift 432 Hz Verification — Spectrum")
            plt.legend()
            plt.grid(True, alpha=0.3)
            plt.tight_layout()
            plot_path = Path(args.input).stem + "_spectrum.png"
            plt.savefig(plot_path, dpi=150)
            print(f"\n  Spectrum saved: {plot_path}")
        except ImportError:
            print("  (Install matplotlib for spectrum plot: pip install matplotlib)")

    return results


def main():
    parser = argparse.ArgumentParser(
        description="AudioShift 432 Hz frequency verification",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("--input",  "-i", required=True, help="Audio file to analyze (.wav, .flac, .raw)")
    parser.add_argument("--expected",     type=float, default=EXPECTED_HZ_DEFAULT,  help="Expected frequency (default: 432.0)")
    parser.add_argument("--tolerance",    type=float, default=TOLERANCE_HZ_DEFAULT, help="Pass/fail tolerance in Hz (default: 2.0)")
    parser.add_argument("--report", "-r", default=None, help="Save JSON report to file")
    parser.add_argument("--plot",   "-p", action="store_true", help="Save spectrum plot as PNG")
    args = parser.parse_args()

    if not Path(args.input).exists():
        print(f"[ERROR] File not found: {args.input}", file=sys.stderr)
        sys.exit(1)

    results = analyze(args)

    if args.report:
        # Remove non-serializable numpy arrays
        for m in results.get("measurements", {}).values():
            m.pop("freqs", None)
            m.pop("magnitudes", None)
        with open(args.report, "w") as f:
            json.dump(results, f, indent=2)
        print(f"\n  Report saved: {args.report}")

    sys.exit(0 if results["verdict"] == "PASS" else 1)


if __name__ == "__main__":
    main()
