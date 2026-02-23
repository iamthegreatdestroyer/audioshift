"""
test_fft_analysis.py — Pytest suite for the quadratic-interpolation FFT
                       frequency detector used in AudioShift verification.

Validates that the algorithm (from verify_432hz.py / AudioShift host tooling)
correctly identifies:
  - 432 Hz test signals
  - 440 Hz test signals (not confused with 432 Hz)
  - Edge cases: silence, DC, Nyquist-adjacent tones

Algorithm under test:
    k = np.argmax(mag)
    d = 0.5 * (mag[k-1] - mag[k+1]) / (mag[k-1] - 2*mag[k] + mag[k+1])
    freq = (k + d) * sample_rate / N

This gives sub-0.5 Hz accuracy for pure sinusoids, which is required to
distinguish 432 Hz from 440 Hz (an 8 Hz difference).

Run:
    pytest tests/unit/test_fft_analysis.py -v
    pytest tests/unit/test_fft_analysis.py -v --tb=short
"""

import math
import numpy as np
import pytest


# ── FFT-based frequency detector (replicated from verify_432hz.py) ─────────

def generate_sine(freq_hz: float, sample_rate: int = 48000,
                  duration_s: float = 1.0,
                  amplitude: float = 1.0) -> np.ndarray:
    """Generate a mono sine wave as a float32 array."""
    n = int(sample_rate * duration_s)
    t = np.arange(n, dtype=np.float64) / sample_rate
    return (amplitude * np.sin(2.0 * math.pi * freq_hz * t)).astype(np.float32)


def detect_frequency_fft(signal: np.ndarray, sample_rate: int = 48000) -> float:
    """
    Estimate the dominant frequency via FFT magnitude peak + quadratic
    interpolation (Parabolic vertex fit).

    Returns:
        Estimated frequency in Hz.  Returns 0.0 for silence.
    Raises:
        ValueError: If signal is too short for reliable detection (< 0.1 s).
    """
    n = len(signal)
    if n < sample_rate // 10:
        raise ValueError(f"Signal too short: {n} samples (need ≥ {sample_rate // 10})")

    # Apply Hann window to reduce spectral leakage
    window = np.hanning(n)
    windowed = signal * window

    # FFT — only use positive frequencies (0 … Nyquist)
    spectrum = np.fft.rfft(windowed)
    mag = np.abs(spectrum)

    # Silence guard
    if mag.max() < 1e-9:
        return 0.0

    # Find peak bin (exclude DC at k=0 and Nyquist at k=len-1)
    k = int(np.argmax(mag[1:-1])) + 1

    # Quadratic interpolation (parabolic vertex fit)
    if k == 0 or k == len(mag) - 1:
        # Peak at edge — return bin frequency directly
        return float(k * sample_rate / n)

    alpha = mag[k - 1]
    beta  = mag[k]
    gamma = mag[k + 1]
    denom = alpha - 2.0 * beta + gamma
    d = 0.5 * (alpha - gamma) / denom if denom != 0.0 else 0.0

    return float((k + d) * sample_rate / n)


def detect_frequency_zero_crossing(signal: np.ndarray,
                                   sample_rate: int = 48000) -> float:
    """
    Estimate frequency via zero-crossing count.  Coarser than FFT but
    completely independent — used in three-method consensus.
    """
    crossings = np.where(np.diff(np.sign(signal)))[0]
    if len(crossings) < 2:
        return 0.0
    n_crossings = len(crossings)
    # Each full period has 2 crossings; duration spans first to last crossing
    duration = (crossings[-1] - crossings[0]) / sample_rate
    return float((n_crossings - 1) / (2.0 * duration)) if duration > 0 else 0.0


def detect_frequency_autocorrelation(signal: np.ndarray,
                                     sample_rate: int = 48000) -> float:
    """
    Estimate frequency via autocorrelation peak.  Independent of FFT windowing.
    """
    n = len(signal)
    # Full autocorrelation
    r = np.correlate(signal.astype(np.float64),
                     signal.astype(np.float64), mode='full')
    r = r[n - 1:]  # keep zero-lag and positive-lag

    # Ignore DC lag — search from lag 10 samples onwards
    min_lag = max(10, int(sample_rate / 4000))  # above 4 kHz for safety
    r[:min_lag] = 0.0

    peak_lag = int(np.argmax(r))
    if peak_lag == 0:
        return 0.0
    return float(sample_rate / peak_lag)


def consensus_frequency(signal: np.ndarray, sample_rate: int = 48000) -> float:
    """Return the median of three independent frequency estimates."""
    fft_f   = detect_frequency_fft(signal, sample_rate)
    zc_f    = detect_frequency_zero_crossing(signal, sample_rate)
    ac_f    = detect_frequency_autocorrelation(signal, sample_rate)
    return float(np.median([fft_f, zc_f, ac_f]))


# ── Constants ─────────────────────────────────────────────────────────────

SAMPLE_RATE   = 48000
DURATION_S    = 1.0       # 1 second gives plenty of frequency resolution
FFT_TOLERANCE = 0.5       # sub-0.5 Hz FFT accuracy requirement
ZC_TOLERANCE  = 2.0       # zero-crossing rougher but within 2 Hz
CONSENSUS_TOL = 2.0       # three-method median within 2 Hz


# ══════════════════════════════════════════════════════════════════════════════
# Test class: TestFftFrequencyDetection
# ══════════════════════════════════════════════════════════════════════════════

class TestFftFrequencyDetection:
    """Core FFT detector tests — validates quadratic interpolation accuracy."""

    def test_detects_432_hz_within_half_hz(self):
        """Primary requirement: 432 Hz tone detected within ±0.5 Hz."""
        sig = generate_sine(432.0, SAMPLE_RATE, DURATION_S)
        detected = detect_frequency_fft(sig, SAMPLE_RATE)
        assert abs(detected - 432.0) <= FFT_TOLERANCE, (
            f"Expected ≈432.0 Hz, got {detected:.4f} Hz "
            f"(error {abs(detected-432.0):.4f} Hz > {FFT_TOLERANCE} Hz)"
        )

    def test_detects_440_hz_within_half_hz(self):
        """440 Hz (A4 concert pitch) also detected accurately."""
        sig = generate_sine(440.0, SAMPLE_RATE, DURATION_S)
        detected = detect_frequency_fft(sig, SAMPLE_RATE)
        assert abs(detected - 440.0) <= FFT_TOLERANCE, (
            f"Expected ≈440.0 Hz, got {detected:.4f} Hz"
        )

    def test_432_hz_and_440_hz_distinguishable(self):
        """432 Hz and 440 Hz must not be confused — they are 8 Hz apart."""
        sig_432 = generate_sine(432.0, SAMPLE_RATE, DURATION_S)
        sig_440 = generate_sine(440.0, SAMPLE_RATE, DURATION_S)
        f_432 = detect_frequency_fft(sig_432, SAMPLE_RATE)
        f_440 = detect_frequency_fft(sig_440, SAMPLE_RATE)
        assert f_432 < 436.0, f"432 Hz signal detected at {f_432:.2f} Hz (too high)"
        assert f_440 > 436.0, f"440 Hz signal detected at {f_440:.2f} Hz (too low)"

    def test_detects_1000_hz(self):
        """Mid-range frequency — basic sanity check for the detector."""
        sig = generate_sine(1000.0, SAMPLE_RATE, DURATION_S)
        detected = detect_frequency_fft(sig, SAMPLE_RATE)
        assert abs(detected - 1000.0) <= FFT_TOLERANCE

    def test_detects_100_hz(self):
        """Low frequency (bass range) — longer period tests interpolation."""
        sig = generate_sine(100.0, SAMPLE_RATE, DURATION_S)
        detected = detect_frequency_fft(sig, SAMPLE_RATE)
        assert abs(detected - 100.0) <= FFT_TOLERANCE

    def test_detects_880_hz(self):
        """A5 — one octave above concert pitch, common in test suites."""
        sig = generate_sine(880.0, SAMPLE_RATE, DURATION_S)
        detected = detect_frequency_fft(sig, SAMPLE_RATE)
        assert abs(detected - 880.0) <= FFT_TOLERANCE

    def test_amplitude_does_not_affect_frequency_estimate(self):
        """Frequency detection must be amplitude-independent."""
        for amp in [0.001, 0.1, 0.5, 1.0]:
            sig = generate_sine(432.0, SAMPLE_RATE, DURATION_S, amplitude=amp)
            detected = detect_frequency_fft(sig, SAMPLE_RATE)
            assert abs(detected - 432.0) <= FFT_TOLERANCE, (
                f"Amplitude {amp}: detected {detected:.4f} Hz, expected 432.0 Hz"
            )

    def test_silence_returns_zero(self):
        """Silent input must return 0.0 Hz, not raise."""
        silence = np.zeros(SAMPLE_RATE, dtype=np.float32)
        detected = detect_frequency_fft(silence, SAMPLE_RATE)
        assert detected == pytest.approx(0.0, abs=1e-9)

    def test_dc_signal_returns_zero_or_near_dc(self):
        """DC-only signal (constant value) — peak is at 0 Hz."""
        dc = np.ones(SAMPLE_RATE, dtype=np.float32)
        detected = detect_frequency_fft(dc, SAMPLE_RATE)
        # Detector skips k=0 (DC), so returns next-highest bin or 0.0
        assert detected < 10.0, f"DC signal detected at {detected:.2f} Hz (expected near 0)"

    def test_short_signal_raises_value_error(self):
        """Signals shorter than 0.1 s should raise ValueError."""
        too_short = generate_sine(432.0, SAMPLE_RATE, duration_s=0.05)
        with pytest.raises(ValueError):
            detect_frequency_fft(too_short, SAMPLE_RATE)

    def test_different_sample_rates(self):
        """Detector must honour the sample_rate parameter."""
        for sr in [44100, 48000]:
            sig = generate_sine(432.0, sample_rate=sr, duration_s=1.0)
            detected = detect_frequency_fft(sig, sr)
            assert abs(detected - 432.0) <= FFT_TOLERANCE, (
                f"sample_rate={sr}: detected {detected:.4f} Hz"
            )


# ══════════════════════════════════════════════════════════════════════════════
# Test class: TestQuadraticInterpolation
# ══════════════════════════════════════════════════════════════════════════════

class TestQuadraticInterpolation:
    """Tests that prove the quadratic interpolation formula is correctly coded."""

    def test_on_bin_frequency_no_interpolation_needed(self):
        """
        If the signal frequency falls exactly on an FFT bin, d ≈ 0
        and the estimate equals the bin frequency directly.
        """
        # N=48000 samples at 48000 Hz → bin width = 1 Hz; 432 Hz is exactly bin 432
        n = SAMPLE_RATE  # exactly 1 second → 1 Hz bin resolution
        t = np.arange(n, dtype=np.float64) / SAMPLE_RATE
        sig = np.sin(2.0 * math.pi * 432.0 * t).astype(np.float32)
        detected = detect_frequency_fft(sig, SAMPLE_RATE)
        assert abs(detected - 432.0) < 0.01, (
            f"On-bin frequency should have near-zero interpolation, got {detected:.6f} Hz"
        )

    def test_half_bin_offset(self):
        """
        Frequency at bin + 0.5 Hz — maximum interpolation demand.
        Result must still be within ±0.5 Hz.
        """
        target = 432.5  # half a bin off from 432.0 (bin width = 1 Hz)
        sig = generate_sine(target, SAMPLE_RATE, DURATION_S)
        detected = detect_frequency_fft(sig, SAMPLE_RATE)
        assert abs(detected - target) <= FFT_TOLERANCE

    def test_quarter_bin_offset(self):
        """Quarter-bin offset — should be well within tolerance."""
        target = 432.25
        sig = generate_sine(target, SAMPLE_RATE, DURATION_S)
        detected = detect_frequency_fft(sig, SAMPLE_RATE)
        assert abs(detected - target) <= FFT_TOLERANCE


# ══════════════════════════════════════════════════════════════════════════════
# Test class: TestConsensusDetection
# ══════════════════════════════════════════════════════════════════════════════

class TestConsensusDetection:
    """Tests for the three-method median consensus detector."""

    def test_consensus_432_hz(self):
        sig = generate_sine(432.0, SAMPLE_RATE, DURATION_S)
        f = consensus_frequency(sig, SAMPLE_RATE)
        assert abs(f - 432.0) <= CONSENSUS_TOL, f"Consensus gave {f:.2f} Hz"

    def test_consensus_440_hz(self):
        sig = generate_sine(440.0, SAMPLE_RATE, DURATION_S)
        f = consensus_frequency(sig, SAMPLE_RATE)
        assert abs(f - 440.0) <= CONSENSUS_TOL, f"Consensus gave {f:.2f} Hz"

    def test_consensus_distinguishes_432_from_440(self):
        f_432 = consensus_frequency(generate_sine(432.0, SAMPLE_RATE, DURATION_S), SAMPLE_RATE)
        f_440 = consensus_frequency(generate_sine(440.0, SAMPLE_RATE, DURATION_S), SAMPLE_RATE)
        assert f_432 < 436.0
        assert f_440 >= 436.0

    def test_consensus_returns_float(self):
        sig = generate_sine(432.0, SAMPLE_RATE, DURATION_S)
        result = consensus_frequency(sig, SAMPLE_RATE)
        assert isinstance(result, float), f"Expected float, got {type(result)}"


# ══════════════════════════════════════════════════════════════════════════════
# Test class: TestPitchShiftVerification
# ══════════════════════════════════════════════════════════════════════════════

class TestPitchShiftVerification:
    """Simulate what the AudioShift module does: shift 440 Hz → 432 Hz."""

    def _pitch_shift_naive(self, signal: np.ndarray, ratio: float,
                           sample_rate: int = 48000) -> np.ndarray:
        """
        Very simple pitch shift via time-domain resampling.
        Not production quality, but good enough to generate a 432 Hz
        signal from 440 Hz for a frequency detection test.
        """
        n_in  = len(signal)
        n_out = int(n_in / ratio)
        indices = np.linspace(0, n_in - 1, n_out)
        # Linear interpolation
        idx_floor = indices.astype(int)
        idx_floor = np.clip(idx_floor, 0, n_in - 2)
        frac = indices - idx_floor
        resampled = (signal[idx_floor] * (1.0 - frac) +
                     signal[idx_floor + 1] * frac)
        return resampled.astype(np.float32)

    def test_440_shifted_to_432_detected_correctly(self):
        """
        Pitch-shift 440 Hz sine by 432/440 ratio → expected frequency 432 Hz.
        This mirrors what AudioShift does at the audio-effect level.
        """
        ratio = 432.0 / 440.0
        sig_440 = generate_sine(440.0, SAMPLE_RATE, DURATION_S)

        # Shifting down by ratio means reading every (1/ratio) samples → resample
        sig_432 = self._pitch_shift_naive(sig_440, 1.0 / ratio, SAMPLE_RATE)

        detected = detect_frequency_fft(sig_432, SAMPLE_RATE)
        assert abs(detected - 432.0) <= 1.0, (
            f"After 440→432 pitch shift, detected {detected:.2f} Hz (expected 432 Hz ±1 Hz)"
        )

    def test_already_432_unchanged(self):
        """Applying ratio=1.0 (no shift) should give the same frequency."""
        sig = generate_sine(432.0, SAMPLE_RATE, DURATION_S)
        shifted = self._pitch_shift_naive(sig, 1.0, SAMPLE_RATE)
        detected = detect_frequency_fft(shifted, SAMPLE_RATE)
        assert abs(detected - 432.0) <= FFT_TOLERANCE


# ══════════════════════════════════════════════════════════════════════════════
# Parametrised edge-case sweep
# ══════════════════════════════════════════════════════════════════════════════

@pytest.mark.parametrize("freq_hz", [
    50.0,    # very low — piano bass
    200.0,
    432.0,   # AudioShift primary target
    440.0,   # concert pitch
    880.0,
    2000.0,
    8000.0,  # high — well within human hearing
])
def test_fft_accuracy_for_various_frequencies(freq_hz):
    """FFT frequency detector must be accurate across the audible range."""
    sig = generate_sine(freq_hz, SAMPLE_RATE, DURATION_S)
    detected = detect_frequency_fft(sig, SAMPLE_RATE)
    assert abs(detected - freq_hz) <= FFT_TOLERANCE, (
        f"freq={freq_hz} Hz: got {detected:.4f} Hz "
        f"(error {abs(detected-freq_hz):.4f} > {FFT_TOLERANCE})"
    )
