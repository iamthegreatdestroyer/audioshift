/**
 * sine_generator.h
 *
 * SineGenerator — produce exact-frequency sine-wave buffers in float or
 * PCM-16 format.  Used by AudioShift integration tests to generate known
 * reference tones; the output can be pitched through the effect library and
 * then analysed by FrequencyValidator.
 *
 * Thread-safety: each SineGenerator instance is independent and stateful
 * (phase-continuous across calls to generate()).  Do not share a single
 * instance across threads without external locking.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#pragma once

#include <cstdint>
#include <vector>

namespace audioshift {
namespace testing {

/**
 * Generates phase-continuous sine-wave buffers.
 *
 * Example
 * ───────
 *   SineGenerator gen(440.0f, 48000, 2);   // 440 Hz, 48 kHz, stereo
 *   auto floats = gen.generateFloat(480);   // 10 ms
 *   auto pcm    = gen.generatePcm16(480);   // same tone, PCM-16
 */
class SineGenerator {
public:
    /**
     * @param frequencyHz   Tone frequency in Hz (must be > 0 and < sample_rate/2).
     * @param sampleRate    Sample rate in Hz (e.g. 48000).
     * @param channels      Number of interleaved channels (1 or 2).
     * @param amplitudeFs   Peak amplitude as a fraction of full-scale [0, 1].
     *                      Default 0.5 leaves headroom to avoid clipping.
     */
    explicit SineGenerator(float    frequencyHz,
                           uint32_t sampleRate  = 48000,
                           uint32_t channels    = 2,
                           float    amplitudeFs = 0.5f);

    // Non-copyable; movable.
    SineGenerator(const SineGenerator &) = delete;
    SineGenerator &operator=(const SineGenerator &) = delete;
    SineGenerator(SineGenerator &&)                 = default;

    // ── Generators ────────────────────────────────────────────────────────

    /**
     * Generate @p frames frames of interleaved float audio [-1, 1].
     * Phase is maintained across successive calls.
     *
     * @param frames  Number of audio frames (each frame = @p channels_ samples).
     * @return        Interleaved float buffer, length = frames × channels.
     */
    [[nodiscard]] std::vector<float> generateFloat(uint32_t frames);

    /**
     * Generate @p frames frames of interleaved int16_t PCM audio.
     * Internally calls generateFloat and scales by 32767.
     *
     * @param frames  Number of audio frames.
     * @return        Interleaved int16_t buffer, length = frames × channels.
     */
    [[nodiscard]] std::vector<int16_t> generatePcm16(uint32_t frames);

    // ── Accessors ─────────────────────────────────────────────────────────

    float    frequencyHz() const noexcept { return frequencyHz_; }
    uint32_t sampleRate()  const noexcept { return sampleRate_;  }
    uint32_t channels()    const noexcept { return channels_;    }
    float    amplitudeFs() const noexcept { return amplitudeFs_; }

    /** Reset internal phase accumulator to zero. */
    void resetPhase() noexcept { phaseRad_ = 0.0; }

    /**
     * Change the frequency without restarting the generator.
     * The next call to generateFloat/Pcm16 will smoothly transition.
     */
    void setFrequency(float newFrequencyHz) noexcept;

private:
    float    frequencyHz_;
    uint32_t sampleRate_;
    uint32_t channels_;
    float    amplitudeFs_;
    double   phaseRad_{0.0};  // phase accumulator (radians)
    double   phaseIncrement_; // 2π × freq / sample_rate, pre-computed
};

}  // namespace testing
}  // namespace audioshift
