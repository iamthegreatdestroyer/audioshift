/**
 * test_pcm_conversion.cpp — Unit tests for PCM16 ↔ float sample conversion
 *
 * The AudioShift effect plug-in converts PCM-16 audio buffers to 32-bit
 * floating-point (±1.0) before passing them through the SoundTouch WSOLA
 * engine, then converts back.  These tests verify:
 *
 *   1. pcm16ToFloat:  INT16 range [-32768, 32767] → float [-1.0, +1.0]
 *   2. floatToPcm16:  float ±1.0 → INT16, with hard saturation outside ±1.0
 *   3. Roundtrip fidelity within ±1 LSB of the INT16 range
 *   4. Special values: 0, INT16_MIN, INT16_MAX, ±0.5, ±0.25
 *   5. Saturation clamping for floats outside the [-1.0, +1.0] band
 *
 * The conversion functions are internal (anonymous namespace in the .cpp).
 * These tests replicate the same arithmetic to validate the algorithm, and
 * also exercise the full pipeline at the ABI boundary in test_effect_context.
 */

#include <gtest/gtest.h>

#include <cstdint>
#include <cmath>
#include <climits>
#include <algorithm>

// ── Reference implementation (mirror of audioshift_hook.cpp) ──────────────
//
// AudioShift uses:
//   float = pcm16 / 32768.0f          (not 32767 — avoids positive asymmetry)
//   pcm16 = clamp(float * 32768.0f, -32768, 32767)

static constexpr float PCM16_SCALE = 32768.0f;
static constexpr float PCM16_INV_SCALE = 1.0f / PCM16_SCALE;

static inline float pcm16ToFloat(int16_t s)
{
    return static_cast<float>(s) * PCM16_INV_SCALE;
}

static inline int16_t floatToPcm16(float f)
{
    float scaled = f * PCM16_SCALE;
    // Hard saturation: no soft-knee, matches Android AEC/AGC expectation
    if (scaled >= 32767.0f)
        return INT16_MAX;
    if (scaled <= -32768.0f)
        return INT16_MIN;
    return static_cast<int16_t>(scaled);
}

// ══════════════════════════════════════════════════════════════════════════════
// Test suite: PcmConversionTest
// ══════════════════════════════════════════════════════════════════════════════

class PcmConversionTest : public ::testing::Test
{
};

// ── pcm16ToFloat boundary values ──────────────────────────────────────────

TEST_F(PcmConversionTest, ZeroMapsToZero)
{
    EXPECT_FLOAT_EQ(pcm16ToFloat(0), 0.0f);
}

TEST_F(PcmConversionTest, Int16MaxMapsNearPositiveOne)
{
    float val = pcm16ToFloat(INT16_MAX); // 32767 / 32768 ≈ 0.999969…
    EXPECT_GT(val, 0.999f);
    EXPECT_LT(val, 1.0f);
}

TEST_F(PcmConversionTest, Int16MinMapsToNegativeOne)
{
    // -32768 / 32768 == -1.0 exactly (power-of-two symmetry)
    EXPECT_FLOAT_EQ(pcm16ToFloat(INT16_MIN), -1.0f);
}

TEST_F(PcmConversionTest, HalfMaxMapsToHalf)
{
    // 16384 / 32768 == 0.5 exactly
    EXPECT_FLOAT_EQ(pcm16ToFloat(16384), 0.5f);
}

TEST_F(PcmConversionTest, NegativeHalfMapsToNegativeHalf)
{
    // -16384 / 32768 == -0.5 exactly
    EXPECT_FLOAT_EQ(pcm16ToFloat(-16384), -0.5f);
}

TEST_F(PcmConversionTest, QuarterMapsToQuarter)
{
    EXPECT_FLOAT_EQ(pcm16ToFloat(8192), 0.25f);
}

TEST_F(PcmConversionTest, OutputIsWithinNegativeOneToPositiveOne)
{
    // Sweep the full signed 16-bit range
    for (int i = INT16_MIN; i <= INT16_MAX; ++i)
    {
        float f = pcm16ToFloat(static_cast<int16_t>(i));
        ASSERT_GE(f, -1.0f) << "Value below -1.0 at i=" << i;
        ASSERT_LE(f, 1.0f) << "Value above +1.0 at i=" << i;
    }
}

TEST_F(PcmConversionTest, MonotonicallyIncreasing)
{
    // Larger PCM16 → larger float (monotonic)
    for (int i = INT16_MIN; i < INT16_MAX; ++i)
    {
        float a = pcm16ToFloat(static_cast<int16_t>(i));
        float b = pcm16ToFloat(static_cast<int16_t>(i + 1));
        ASSERT_LE(a, b) << "Non-monotonic at i=" << i;
    }
}

// ── floatToPcm16 boundary values ──────────────────────────────────────────

TEST_F(PcmConversionTest, PositiveOneToInt16Max)
{
    // 1.0 * 32768 = 32768 → clamped to INT16_MAX (32767)
    EXPECT_EQ(floatToPcm16(1.0f), INT16_MAX);
}

TEST_F(PcmConversionTest, NegativeOneToInt16Min)
{
    // -1.0 * 32768 = -32768 → exactly INT16_MIN
    EXPECT_EQ(floatToPcm16(-1.0f), INT16_MIN);
}

TEST_F(PcmConversionTest, ZeroFloatToZeroPcm)
{
    EXPECT_EQ(floatToPcm16(0.0f), static_cast<int16_t>(0));
}

TEST_F(PcmConversionTest, HalfFloatToHalfPcm)
{
    EXPECT_EQ(floatToPcm16(0.5f), static_cast<int16_t>(16384));
}

TEST_F(PcmConversionTest, NegativeHalfFloatToNegativeHalfPcm)
{
    EXPECT_EQ(floatToPcm16(-0.5f), static_cast<int16_t>(-16384));
}

// ── Saturation / clamping ──────────────────────────────────────────────────

TEST_F(PcmConversionTest, OverdrivePositiveClamps)
{
    // Values above +1.0 must saturate to INT16_MAX
    EXPECT_EQ(floatToPcm16(1.1f), INT16_MAX);
    EXPECT_EQ(floatToPcm16(2.0f), INT16_MAX);
    EXPECT_EQ(floatToPcm16(10.0f), INT16_MAX);
    EXPECT_EQ(floatToPcm16(1e6f), INT16_MAX);
}

TEST_F(PcmConversionTest, OverdriveNegativeClamps)
{
    // Values below -1.0 must saturate to INT16_MIN
    EXPECT_EQ(floatToPcm16(-1.1f), INT16_MIN);
    EXPECT_EQ(floatToPcm16(-2.0f), INT16_MIN);
    EXPECT_EQ(floatToPcm16(-10.0f), INT16_MIN);
    EXPECT_EQ(floatToPcm16(-1e6f), INT16_MIN);
}

TEST_F(PcmConversionTest, JustBelowOneSaturates)
{
    // 0.9999f * 32768 = 32764.67… → 32764, not clamped
    int16_t v = floatToPcm16(0.9999f);
    EXPECT_LT(v, INT16_MAX);
    EXPECT_GT(v, 32760);
}

// ── Roundtrip fidelity ────────────────────────────────────────────────────

TEST_F(PcmConversionTest, RoundtripZero)
{
    int16_t original = 0;
    float f = pcm16ToFloat(original);
    int16_t restored = floatToPcm16(f);
    EXPECT_EQ(restored, original);
}

TEST_F(PcmConversionTest, RoundtripInt16Max)
{
    // INT16_MAX → ~0.999969f → clamps back to INT16_MAX
    int16_t original = INT16_MAX;
    float f = pcm16ToFloat(original);
    int16_t restored = floatToPcm16(f);
    // Allowed 1 LSB error due to float precision, or equal
    EXPECT_LE(std::abs(restored - original), 1);
}

TEST_F(PcmConversionTest, RoundtripInt16Min)
{
    int16_t original = INT16_MIN;
    float f = pcm16ToFloat(original);
    int16_t restored = floatToPcm16(f);
    EXPECT_EQ(restored, original);
}

TEST_F(PcmConversionTest, RoundtripSweep)
{
    // For all INT16 values, pcm→float→pcm must be within ±1 LSB
    int violations = 0;
    for (int i = INT16_MIN; i <= INT16_MAX; ++i)
    {
        int16_t original = static_cast<int16_t>(i);
        float f = pcm16ToFloat(original);
        int16_t restored = floatToPcm16(f);
        if (std::abs(static_cast<int>(restored) - i) > 1)
        {
            ++violations;
        }
    }
    EXPECT_EQ(violations, 0)
        << violations << " values failed the ±1 LSB roundtrip requirement";
}

// ── Noise floor: conversion scale precision ────────────────────────────────

TEST_F(PcmConversionTest, ScaleIs32768NotNormalized)
{
    // Division by 32768 (not 32767) preserves power-of-two alignment.
    // Verify: INT16_MIN / 32768 == -1.0 exactly.
    float min_val = static_cast<float>(INT16_MIN) / 32768.0f;
    EXPECT_FLOAT_EQ(min_val, -1.0f);
}

TEST_F(PcmConversionTest, PositiveAsymmetryWithin1Lsb)
{
    // INT16_MAX / 32768 = 32767/32768 ≈ 0.999969 (not exactly 1.0)
    float max_val = pcm16ToFloat(INT16_MAX);
    EXPECT_LT(max_val, 1.0f);
    EXPECT_GT(max_val, 1.0f - 1.0f / 32768.0f - 1e-6f);
}
