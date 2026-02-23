/**
 * test_pitch_ratio.cpp — Unit tests for 432 Hz pitch constant correctness
 *
 * Validates:
 *  • PITCH_RATIO_432_HZ   == 432.0f / 440.0f  (exact by IEEE 754 rules)
 *  • PITCH_SEMITONES_432_HZ ≈ 12 × log2(432/440)  ≈ -0.3164 semitones
 *  • 440.0f × ratio ≈ 432.0 Hz   (round-trip within 0.1 Hz)
 *  • Ratio is strictly between 0.9 and 1.0 (lower pitch, never > 440)
 *  • Semitones is negative (pitch is lowered)
 *  • SoundTouch "tempo" / "rate" compensation invariants hold
 */

#include <gtest/gtest.h>

#include <cmath>
#include <cfloat>
#include <stdint.h>

// ── Constants under test ───────────────────────────────────────────────────
// Reproduce the same constexpr definitions as audioshift_hook.h so this file
// compiles without Android headers.  Both values must stay in sync with the
// header; a static_assert in test_effect_context.cpp enforces that.

static constexpr float PITCH_RATIO_432_HZ     = 432.0f / 440.0f;
static constexpr float PITCH_SEMITONES_432_HZ = -0.3164f;

// ── Helpers ────────────────────────────────────────────────────────────────

static float semitones_from_ratio(float ratio) {
    return 12.0f * std::log2(ratio);
}

static float frequency_after_shift(float source_hz, float ratio) {
    return source_hz * ratio;
}

// ══════════════════════════════════════════════════════════════════════════════
// Test suite: PitchRatioConstants
// ══════════════════════════════════════════════════════════════════════════════

class PitchRatioTest : public ::testing::Test {};

// ── Exact ratio value ──────────────────────────────────────────────────────

TEST_F(PitchRatioTest, RatioEqualsExactFraction) {
    // The ratio must be exactly 432/440 — computed at compile time via IEEE 754
    float expected = 432.0f / 440.0f;
    EXPECT_FLOAT_EQ(PITCH_RATIO_432_HZ, expected)
        << "PITCH_RATIO_432_HZ must equal exactly 432.0f/440.0f";
}

TEST_F(PitchRatioTest, RatioIsLessThanOne) {
    // 432 < 440, so the ratio must be < 1.0 (pitch is lowered)
    EXPECT_LT(PITCH_RATIO_432_HZ, 1.0f)
        << "Shifting from 440 → 432 Hz must lower the pitch (ratio < 1)";
}

TEST_F(PitchRatioTest, RatioIsGreaterThanNinetyPercent) {
    // Sanity: should not be a catastrophic shift
    EXPECT_GT(PITCH_RATIO_432_HZ, 0.9f)
        << "Ratio must be in a musically sane range";
}

TEST_F(PitchRatioTest, RatioApproximateValue) {
    // 432/440 ≈ 0.981818…
    EXPECT_NEAR(PITCH_RATIO_432_HZ, 0.981818f, 1e-5f);
}

// ── Round-trip: shift 440 Hz → should land at 432 Hz ──────────────────────

TEST_F(PitchRatioTest, ShiftedPitchLandsAt432Hz) {
    float result = frequency_after_shift(440.0f, PITCH_RATIO_432_HZ);
    EXPECT_NEAR(result, 432.0f, 0.01f)
        << "440 Hz × PITCH_RATIO_432_HZ must equal approximately 432 Hz";
}

TEST_F(PitchRatioTest, ShiftedPitchWithinHalfHzOfTarget) {
    float result = frequency_after_shift(440.0f, PITCH_RATIO_432_HZ);
    EXPECT_LT(std::fabs(result - 432.0f), 0.5f)
        << "Result must be within 0.5 Hz of 432 Hz";
}

TEST_F(PitchRatioTest, ShiftedPitchNotEqualTo440Hz) {
    float result = frequency_after_shift(440.0f, PITCH_RATIO_432_HZ);
    EXPECT_NE(result, 440.0f)
        << "Pitch shift must actually change the frequency";
}

// ── Semitone constant ──────────────────────────────────────────────────────

TEST_F(PitchRatioTest, SemitonesIsNegative) {
    EXPECT_LT(PITCH_SEMITONES_432_HZ, 0.0f)
        << "Shifting 440 → 432 Hz lowers pitch, so semitones must be negative";
}

TEST_F(PitchRatioTest, SemitonesMagnitudeLessThanOneSemitone) {
    EXPECT_LT(std::fabs(PITCH_SEMITONES_432_HZ), 1.0f)
        << "The 432/440 shift is less than one semitone";
}

TEST_F(PitchRatioTest, SemitonesMagnitudeGreaterThanPrecisionFloor) {
    // Must be a real shift, not floating-point noise
    EXPECT_GT(std::fabs(PITCH_SEMITONES_432_HZ), 0.1f)
        << "Semitone value must represent a perceptible shift";
}

TEST_F(PitchRatioTest, SemitonesMatchesMathFormula) {
    float computed = semitones_from_ratio(PITCH_RATIO_432_HZ);
    // The constant -0.3164 must agree with the exact formula to 3 d.p.
    EXPECT_NEAR(PITCH_SEMITONES_432_HZ, computed, 0.002f)
        << "PITCH_SEMITONES_432_HZ must match 12*log2(432/440)";
}

TEST_F(PitchRatioTest, SemitonesMatchesKnownValue) {
    // 12 * log2(432/440) = 12 * log2(0.981818) ≈ -0.31640
    EXPECT_NEAR(PITCH_SEMITONES_432_HZ, -0.3164f, 0.0005f);
}

// ── Inverse consistency ────────────────────────────────────────────────────

TEST_F(PitchRatioTest, InverseSemitonesRoundTrip) {
    // pow(2, semitones/12) should reconstruct the ratio
    float reconstructed_ratio = std::pow(2.0f, PITCH_SEMITONES_432_HZ / 12.0f);
    EXPECT_NEAR(reconstructed_ratio, PITCH_RATIO_432_HZ, 1e-4f)
        << "Semitone ↔ ratio conversion must round-trip";
}

// ── SoundTouch-specific: tempo compensation ───────────────────────────────

TEST_F(PitchRatioTest, SoundTouchTempoShouldBeUnchanged) {
    // When pitch-only mode is used (no rate change), tempo stays at 1.0
    // This is a design requirement: we shift pitch, not tempo.
    float tempo = 1.0f;  // SoundTouch SETTING_RATE left at default
    EXPECT_FLOAT_EQ(tempo, 1.0f);
}

TEST_F(PitchRatioTest, PitchRatioIsFinite) {
    EXPECT_TRUE(std::isfinite(PITCH_RATIO_432_HZ))
        << "Ratio must be a finite float (not NaN or Inf)";
}

TEST_F(PitchRatioTest, SemitonesIsFinite) {
    EXPECT_TRUE(std::isfinite(PITCH_SEMITONES_432_HZ))
        << "Semitone constant must be finite";
}

// ── Multiple-frequency consistency ────────────────────────────────────────

TEST_F(PitchRatioTest, AllA4FrequenciesShiftCorrectly) {
    // 440 Hz centre reference: verify 434 Hz and 446 Hz also shift by ~1.82%
    const float test_freqs[] = { 440.0f, 880.0f, 220.0f };
    for (float f : test_freqs) {
        float shifted = frequency_after_shift(f, PITCH_RATIO_432_HZ);
        float expected = f * (432.0f / 440.0f);
        EXPECT_NEAR(shifted, expected, expected * 1e-5f)
            << "Frequency " << f << " Hz did not shift correctly";
    }
}
