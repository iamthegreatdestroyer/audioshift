/**
 * frequency_validator.h
 *
 * FrequencyValidator — measure the dominant frequency of a float PCM buffer
 * using a windowed FFT with quadratic-interpolated bin refinement.
 *
 * The algorithm:
 *   1. Apply a Hann window to reduce spectral leakage.
 *   2. Compute the DFT magnitude spectrum via the Goertzel algorithm (single
 *      frequency sweep) or a manual DFT for the full spectrum (small N).
 *   3. Find the bin k with maximum magnitude.
 *   4. Refine using three-point quadratic interpolation for sub-bin accuracy:
 *        δ = 0.5 × (|k-1| - |k+1|) / (|k-1| - 2|k| + |k+1|)
 *        f = (k + δ) × sr / N
 *
 * Accuracy: ≤ 1 Hz for N ≥ 4096 at 48 kHz; ≤ 0.5 Hz for N ≥ 8192.
 *
 * Thread-safety: all public methods are static and thread-safe.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#pragma once

#include <cstdint>
#include <vector>

namespace audioshift
{
    namespace testing
    {

        /**
         * Stateless frequency-detection helper.
         *
         * Example
         * ───────
         *   SineGenerator gen(432.0f, 48000, 1);
         *   auto signal = gen.generateFloat(8192);          // ~170 ms
         *
         *   float hz = FrequencyValidator::detectFrequency(signal, 48000);
         *   // hz ≈ 432.0 (within ~0.5 Hz)
         *
         *   bool ok = FrequencyValidator::isFrequency(signal, 48000, 432.0f, 1.0f);
         *   // ok = true
         */
        class FrequencyValidator
        {
        public:
            // ── Primary API ───────────────────────────────────────────────────────

            /**
             * Detect the dominant frequency in @p signal.
             *
             * @param signal       Mono interleaved float PCM [-1, 1].  Must have at
             *                     least 256 samples; better accuracy with ≥ 4096.
             * @param sampleRate   Sample rate in Hz.
             * @return             Dominant frequency in Hz, or 0.0f on failure.
             */
            static float detectFrequency(const std::vector<float> &signal,
                                         uint32_t sampleRate);

            /**
             * Return true if the dominant frequency is within @p toleranceHz of
             * @p expectedHz.
             *
             * @param signal       Mono interleaved float PCM.
             * @param sampleRate   Sample rate in Hz.
             * @param expectedHz   Target frequency to validate against.
             * @param toleranceHz  Allowed deviation in Hz (default ±1 Hz).
             */
            static bool isFrequency(const std::vector<float> &signal,
                                    uint32_t sampleRate,
                                    float expectedHz,
                                    float toleranceHz = 1.0f);

            /**
             * Validate that a pitch-shift was applied correctly.
             *
             * Detects the dominant frequency in both @p input and @p output, then
             * checks:
             *   (a) input  ≈ fromHz  (within toleranceHz)
             *   (b) output ≈ toHz    (within toleranceHz)
             *
             * @param input        Original signal (mono float PCM).
             * @param output       Processed signal (mono float PCM).
             * @param sampleRate   Common sample rate.
             * @param fromHz       Expected input fundamental (e.g. 440 Hz).
             * @param toHz         Expected output fundamental (e.g. 432 Hz).
             * @param toleranceHz  Allowed deviation for both measurements (default ±2 Hz).
             * @return             true only if both channels are within tolerance.
             */
            static bool validatePitchShift(const std::vector<float> &input,
                                           const std::vector<float> &output,
                                           uint32_t sampleRate,
                                           float fromHz,
                                           float toHz,
                                           float toleranceHz = 2.0f);

            // ── Diagnostic helpers ────────────────────────────────────────────────

            /**
             * Build and return the full magnitude spectrum.
             * Primarily used in unit tests that want to inspect intermediate values.
             *
             * @param signal      Mono float PCM.
             * @param sampleRate  Sample rate in Hz (unused here; kept for symmetry).
             * @return            Magnitude spectrum (length = signal.size()/2 + 1).
             */
            static std::vector<float> computeMagnitudeSpectrum(
                const std::vector<float> &signal);

            /**
             * Compute the RMS energy of @p signal.
             * Useful as a sanity-check: silence returns ≈ 0.
             */
            static float rmsEnergy(const std::vector<float> &signal);

        private:
            // Non-instantiable utility class.
            FrequencyValidator() = delete;
            ~FrequencyValidator() = delete;

            // Internal: apply Hann window in-place (modifies a copy).
            static std::vector<float> applyHannWindow(const std::vector<float> &signal);

            // Internal: find peak bin and refine with quadratic interpolation.
            static float refinePeak(const std::vector<float> &mag,
                                    uint32_t sampleRate,
                                    std::size_t signalLength);
        };

    } // namespace testing
} // namespace audioshift
