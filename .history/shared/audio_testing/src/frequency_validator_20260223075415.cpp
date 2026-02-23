/**
 * frequency_validator.cpp
 *
 * DFT-based frequency detection with:
 *   - Hann windowing (reduces spectral leakage)
 *   - Manual DFT magnitude spectrum (O(N²); fine for N ≤ 32768)
 *   - Quadratic-interpolated peak refinement (sub-bin accuracy)
 *
 * For N = 8192 at 48 kHz, bin resolution = 48000/8192 ≈ 5.86 Hz.
 * After quadratic refinement, accuracy ≲ 0.5 Hz for pure tones.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include "frequency_validator.h"

#include <algorithm>
#include <cassert>
#include <cmath>
#include <cstddef>
#include <stdexcept>

namespace audioshift {
namespace testing {

// ── Helpers (file-internal) ──────────────────────────────────────────────────

namespace {

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

/**
 * Apply a Hann window to reduce spectral leakage.
 * w[n] = 0.5 × (1 − cos(2πn/(N−1)))
 */
std::vector<float> applyHannWindowInternal(const std::vector<float> &signal) {
    const std::size_t N = signal.size();
    std::vector<float> windowed(N);
    const double norm = 2.0 * M_PI / static_cast<double>(N - 1);
    for (std::size_t n = 0; n < N; ++n) {
        const double w = 0.5 * (1.0 - std::cos(norm * static_cast<double>(n)));
        windowed[n]    = static_cast<float>(static_cast<double>(signal[n]) * w);
    }
    return windowed;
}

/**
 * Compute DFT magnitude spectrum for bins 0 … N/2 (inclusive).
 *
 * For each bin k:
 *   re = Σ x[n] × cos(2πkn/N)
 *   im = Σ x[n] × sin(2πkn/N)
 *   mag = sqrt(re²+im²)
 *
 * Complexity O(N²) — acceptable for N ≤ 16384.
 */
std::vector<float> computeDftMagnitude(const std::vector<float> &signal) {
    const std::size_t N    = signal.size();
    const std::size_t half = N / 2 + 1;
    std::vector<float> mag(half, 0.0f);

    const double twoPiOverN = 2.0 * M_PI / static_cast<double>(N);

    for (std::size_t k = 0; k < half; ++k) {
        double re = 0.0;
        double im = 0.0;
        const double kNorm = twoPiOverN * static_cast<double>(k);
        for (std::size_t n = 0; n < N; ++n) {
            const double angle = kNorm * static_cast<double>(n);
            re += static_cast<double>(signal[n]) * std::cos(angle);
            im -= static_cast<double>(signal[n]) * std::sin(angle);
        }
        mag[k] = static_cast<float>(std::sqrt(re * re + im * im));
    }
    return mag;
}

/**
 * Find the peak bin index (excluding DC bin 0 and last bin).
 */
std::size_t findPeakBin(const std::vector<float> &mag) {
    // Start from bin 1 to skip DC.  Leave room for quadratic refinement.
    std::size_t peak = 1;
    for (std::size_t k = 2; k < mag.size() - 1; ++k) {
        if (mag[k] > mag[peak]) {
            peak = k;
        }
    }
    return peak;
}

/**
 * Quadratic-interpolated peak refinement.
 *
 * Given peak bin k and neighbours:
 *   δ = 0.5 × (|k-1| - |k+1|) / (|k-1| - 2|k| + |k+1|)
 *   f_refined = (k + δ) × sr / N
 *
 * Returns 0.0f if curvature is non-negative (degenerate case).
 */
float refinePeakInternal(const std::vector<float> &mag,
                          std::size_t               peak,
                          uint32_t                  sampleRate,
                          std::size_t               N) {
    if (peak == 0 || peak + 1 >= mag.size()) {
        // Cannot interpolate at boundaries.
        return static_cast<float>(peak) * static_cast<float>(sampleRate) /
               static_cast<float>(N);
    }

    const double ym1 = static_cast<double>(mag[peak - 1]);
    const double y0  = static_cast<double>(mag[peak]);
    const double y1  = static_cast<double>(mag[peak + 1]);

    const double denom = ym1 - 2.0 * y0 + y1;
    if (denom >= 0.0) {
        // Non-negative curvature: return unrefined bin frequency.
        return static_cast<float>(peak) * static_cast<float>(sampleRate) /
               static_cast<float>(N);
    }

    const double delta        = 0.5 * (ym1 - y1) / denom;
    const double refinedBin   = static_cast<double>(peak) + delta;
    const double refinedFreq  = refinedBin * static_cast<double>(sampleRate) /
                                 static_cast<double>(N);

    return static_cast<float>(refinedFreq);
}

}  // anonymous namespace

// ── Public: applyHannWindow ──────────────────────────────────────────────────

std::vector<float> FrequencyValidator::applyHannWindow(
    const std::vector<float> &signal) {
    return applyHannWindowInternal(signal);
}

// ── Public: refinePeak ───────────────────────────────────────────────────────

float FrequencyValidator::refinePeak(const std::vector<float> &mag,
                                      uint32_t                  sampleRate,
                                      std::size_t               signalLength) {
    const std::size_t peak = findPeakBin(mag);
    return refinePeakInternal(mag, peak, sampleRate, signalLength);
}

// ── Public: computeMagnitudeSpectrum ─────────────────────────────────────────

std::vector<float> FrequencyValidator::computeMagnitudeSpectrum(
    const std::vector<float> &signal) {
    if (signal.size() < 4) {
        return {};
    }
    const auto windowed = applyHannWindowInternal(signal);
    return computeDftMagnitude(windowed);
}

// ── Public: rmsEnergy ────────────────────────────────────────────────────────

float FrequencyValidator::rmsEnergy(const std::vector<float> &signal) {
    if (signal.empty()) return 0.0f;
    double sum = 0.0;
    for (float s : signal) {
        sum += static_cast<double>(s) * static_cast<double>(s);
    }
    return static_cast<float>(std::sqrt(sum / static_cast<double>(signal.size())));
}

// ── Public: detectFrequency ──────────────────────────────────────────────────

float FrequencyValidator::detectFrequency(const std::vector<float> &signal,
                                           uint32_t                  sampleRate) {
    if (signal.size() < 4 || sampleRate == 0) {
        return 0.0f;
    }

    // Check for silence: avoid returning nonsense on zero input.
    if (rmsEnergy(signal) < 1e-6f) {
        return 0.0f;
    }

    const auto windowed = applyHannWindowInternal(signal);
    const auto mag      = computeDftMagnitude(windowed);

    if (mag.size() < 3) {
        return 0.0f;
    }

    const std::size_t peak = findPeakBin(mag);
    return refinePeakInternal(mag, peak, sampleRate, signal.size());
}

// ── Public: isFrequency ───────────────────────────────────────────────────────

bool FrequencyValidator::isFrequency(const std::vector<float> &signal,
                                      uint32_t                  sampleRate,
                                      float                     expectedHz,
                                      float                     toleranceHz) {
    const float detected = detectFrequency(signal, sampleRate);
    if (detected <= 0.0f) return false;
    return std::abs(detected - expectedHz) <= toleranceHz;
}

// ── Public: validatePitchShift ───────────────────────────────────────────────

bool FrequencyValidator::validatePitchShift(const std::vector<float> &input,
                                             const std::vector<float> &output,
                                             uint32_t                  sampleRate,
                                             float                     fromHz,
                                             float                     toHz,
                                             float                     toleranceHz) {
    const float detectedIn  = detectFrequency(input,  sampleRate);
    const float detectedOut = detectFrequency(output, sampleRate);

    const bool inputOk  = (detectedIn  > 0.0f) &&
                          (std::abs(detectedIn  - fromHz) <= toleranceHz);
    const bool outputOk = (detectedOut > 0.0f) &&
                          (std::abs(detectedOut - toHz)   <= toleranceHz);

    return inputOk && outputOk;
}

}  // namespace testing
}  // namespace audioshift
