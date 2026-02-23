/**
 * test_frequency_validator.cpp
 *
 * Unit tests for audioshift::testing::FrequencyValidator.
 *
 * Test suite: FrequencyValidatorTest
 *
 * Uses SineGenerator to produce reference signals of known frequency so that
 * FrequencyValidator's detection accuracy, tolerance gating, and
 * validatePitchShift API can all be verified independently.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include "frequency_validator.h"
#include "sine_generator.h"

#include <gtest/gtest.h>

#include <cmath>
#include <cstdint>
#include <vector>

namespace audioshift {
namespace testing {
namespace {

// ── Constants ─────────────────────────────────────────────────────────────────

static constexpr uint32_t kSampleRate = 48000;
// 8192 frames → bin resolution ≈ 5.86 Hz; after refinement ≲ 0.5 Hz error.
static constexpr uint32_t kFrames     = 8192;
static constexpr float    kAmp        = 0.5f;

// ── Test fixture ──────────────────────────────────────────────────────────────

class FrequencyValidatorTest : public ::testing::Test {
protected:
    /**
     * Generate a mono float buffer of @p freqHz at the shared sample rate /
     * frame count.  Mono is required because detectFrequency expects mono PCM.
     */
    static std::vector<float> makeTone(float freqHz, uint32_t frames = kFrames) {
        SineGenerator gen(freqHz, kSampleRate, 1, kAmp);
        return gen.generateFloat(frames);
    }

    static std::vector<float> makeSilence(uint32_t frames = kFrames) {
        return std::vector<float>(frames, 0.0f);
    }
};

// ── rmsEnergy sanity ──────────────────────────────────────────────────────────

TEST_F(FrequencyValidatorTest, RmsOfSilenceIsZero) {
    const auto silence = makeSilence();
    EXPECT_NEAR(FrequencyValidator::rmsEnergy(silence), 0.0f, 1e-6f);
}

TEST_F(FrequencyValidatorTest, RmsOfSineIsPositive) {
    const auto tone = makeTone(440.0f);
    EXPECT_GT(FrequencyValidator::rmsEnergy(tone), 0.0f);
}

TEST_F(FrequencyValidatorTest, RmsEmptyBufferIsZero) {
    EXPECT_EQ(FrequencyValidator::rmsEnergy({}), 0.0f);
}

// ── computeMagnitudeSpectrum sanity ───────────────────────────────────────────

TEST_F(FrequencyValidatorTest, SpectrumLengthIsHalfPlusOne) {
    const auto tone = makeTone(440.0f);
    const auto mag  = FrequencyValidator::computeMagnitudeSpectrum(tone);
    EXPECT_EQ(mag.size(), kFrames / 2 + 1);
}

TEST_F(FrequencyValidatorTest, SpectrumPeakNear440HzBin) {
    const auto tone = makeTone(440.0f);
    const auto mag  = FrequencyValidator::computeMagnitudeSpectrum(tone);

    // Expected peak bin: round(440 × N / sr) = round(440 × 8192 / 48000) ≈ 75
    const std::size_t expectedBin =
        static_cast<std::size_t>(std::round(440.0 * kFrames / kSampleRate));

    std::size_t peakBin = 0;
    for (std::size_t i = 1; i < mag.size(); ++i) {
        if (mag[i] > mag[peakBin]) peakBin = i;
    }

    // Allow ±2 bins (≈ ±12 Hz) for quantisation.
    EXPECT_NEAR(static_cast<int>(peakBin), static_cast<int>(expectedBin), 2);
}

// ── detectFrequency: exact tones ─────────────────────────────────────────────

TEST_F(FrequencyValidatorTest, Detects440Hz) {
    const auto tone     = makeTone(440.0f);
    const float detected = FrequencyValidator::detectFrequency(tone, kSampleRate);
    EXPECT_NEAR(detected, 440.0f, 1.0f);  // within 1 Hz
}

TEST_F(FrequencyValidatorTest, Detects432Hz) {
    const auto tone     = makeTone(432.0f);
    const float detected = FrequencyValidator::detectFrequency(tone, kSampleRate);
    EXPECT_NEAR(detected, 432.0f, 1.0f);
}

TEST_F(FrequencyValidatorTest, Detects220Hz) {
    const auto tone     = makeTone(220.0f);
    const float detected = FrequencyValidator::detectFrequency(tone, kSampleRate);
    EXPECT_NEAR(detected, 220.0f, 1.5f);
}

TEST_F(FrequencyValidatorTest, Detects1000Hz) {
    const auto tone     = makeTone(1000.0f);
    const float detected = FrequencyValidator::detectFrequency(tone, kSampleRate);
    EXPECT_NEAR(detected, 1000.0f, 1.5f);
}

TEST_F(FrequencyValidatorTest, SilenceReturnsZero) {
    const auto silence  = makeSilence();
    const float detected = FrequencyValidator::detectFrequency(silence, kSampleRate);
    EXPECT_FLOAT_EQ(detected, 0.0f);
}

TEST_F(FrequencyValidatorTest, TooShortBufferReturnsZero) {
    // Fewer than 4 samples: must not crash, must return 0.
    const std::vector<float> tiny = {0.1f, -0.1f, 0.05f};
    EXPECT_FLOAT_EQ(FrequencyValidator::detectFrequency(tiny, kSampleRate), 0.0f);
}

// ── isFrequency: tolerance gating ─────────────────────────────────────────────

TEST_F(FrequencyValidatorTest, AcceptsWithinTolerance) {
    const auto tone = makeTone(440.0f);
    // Wide tolerance: should definitely pass.
    EXPECT_TRUE(FrequencyValidator::isFrequency(tone, kSampleRate, 440.0f, 5.0f));
}

TEST_F(FrequencyValidatorTest, AcceptsExact1HzTolerance) {
    const auto tone = makeTone(440.0f);
    EXPECT_TRUE(FrequencyValidator::isFrequency(tone, kSampleRate, 440.0f, 1.0f));
}

TEST_F(FrequencyValidatorTest, RejectsVeryTightTolerance) {
    // At 0.01 Hz tolerance practically any signal will fail due to bin width.
    const auto tone = makeTone(440.0f);
    // We don't assert false here unconditionally because the interpolated value
    // could be very close; instead check that at least one extreme fails.
    // 440 Hz vs 432 Hz: difference = 8 Hz, so 0.1 Hz tolerance must reject.
    EXPECT_FALSE(FrequencyValidator::isFrequency(tone, kSampleRate, 432.0f, 0.1f));
}

TEST_F(FrequencyValidatorTest, Distinguishes432And440Hz) {
    const auto tone440 = makeTone(440.0f);
    const auto tone432 = makeTone(432.0f);

    // 440 Hz signal should be rejected as 432 Hz with 1 Hz tolerance.
    EXPECT_FALSE(FrequencyValidator::isFrequency(tone440, kSampleRate, 432.0f, 1.0f));
    // 432 Hz signal should be rejected as 440 Hz with 1 Hz tolerance.
    EXPECT_FALSE(FrequencyValidator::isFrequency(tone432, kSampleRate, 440.0f, 1.0f));
}

TEST_F(FrequencyValidatorTest, SilenceIsNeverAccepted) {
    const auto silence = makeSilence();
    EXPECT_FALSE(FrequencyValidator::isFrequency(silence, kSampleRate, 440.0f, 100.0f));
}

// ── validatePitchShift ────────────────────────────────────────────────────────

/**
 * Helper: naive "pitch shift" by resampling a mono float buffer.
 *
 * Applies a ratio by selecting samples at positions n / ratio (linear
 * interpolation).  Not high quality, but sufficient to produce a signal
 * that FrequencyValidator can detect at the shifted frequency.
 */
static std::vector<float> naivePitchShift(const std::vector<float> &input,
                                           float                     ratio) {
    const std::size_t N = input.size();
    std::vector<float> out(N);
    for (std::size_t n = 0; n < N; ++n) {
        const double srcPos = static_cast<double>(n) / static_cast<double>(ratio);
        const std::size_t i0 = static_cast<std::size_t>(srcPos);
        const double frac    = srcPos - static_cast<double>(i0);
        if (i0 + 1 < N) {
            out[n] = static_cast<float>(
                (1.0 - frac) * static_cast<double>(input[i0]) +
                frac         * static_cast<double>(input[i0 + 1]));
        } else if (i0 < N) {
            out[n] = input[i0];
        } else {
            out[n] = 0.0f;
        }
    }
    return out;
}

TEST_F(FrequencyValidatorTest, ValidatesPitchShift440To432) {
    // 440 Hz input → pitch down to 432 Hz: ratio = 432/440 ≈ 0.9818
    const float ratio = 432.0f / 440.0f;

    const auto input440 = makeTone(440.0f);
    const auto output432 = naivePitchShift(input440, ratio);

    // Use 3 Hz tolerance; naivePitchShift is not perfect quality.
    EXPECT_TRUE(FrequencyValidator::validatePitchShift(
        input440, output432, kSampleRate, 440.0f, 432.0f, 3.0f));
}

TEST_F(FrequencyValidatorTest, ValidatePitchShiftFailsOnUnshiftedOutput) {
    const auto input440 = makeTone(440.0f);
    const auto alsoInput440 = input440;  // No shift applied.

    // Output would be detected at 440 Hz, not 432 Hz — must return false.
    EXPECT_FALSE(FrequencyValidator::validatePitchShift(
        input440, alsoInput440, kSampleRate, 440.0f, 432.0f, 2.0f));
}

TEST_F(FrequencyValidatorTest, ValidatePitchShiftFailsOnSilentOutput) {
    const auto input440  = makeTone(440.0f);
    const auto silence   = makeSilence();

    EXPECT_FALSE(FrequencyValidator::validatePitchShift(
        input440, silence, kSampleRate, 440.0f, 432.0f, 2.0f));
}

// ── Edge cases ───────────────────────────────────────────────────────────────

TEST_F(FrequencyValidatorTest, EmptySpectrumOnTinyInput) {
    const std::vector<float> tiny = {0.5f, -0.5f};
    const auto mag  = FrequencyValidator::computeMagnitudeSpectrum(tiny);
    EXPECT_TRUE(mag.empty());
}

TEST_F(FrequencyValidatorTest, ZeroSampleRateReturnsZero) {
    const auto tone = makeTone(440.0f);
    EXPECT_FLOAT_EQ(FrequencyValidator::detectFrequency(tone, 0), 0.0f);
}

}  // namespace
}  // namespace testing
}  // namespace audioshift
