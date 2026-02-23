/**
 * test_sine_generator.cpp
 *
 * Unit tests for audioshift::testing::SineGenerator.
 *
 * Test suite: SineGeneratorTest
 *
 * All tests work on a mono channel to keep FFT simple.  Stereo / multi-channel
 * layout is verified by separate length- and content-equality tests.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include "sine_generator.h"
#include "frequency_validator.h"

#include <gtest/gtest.h>

#include <cmath>
#include <cstdint>
#include <numeric>
#include <vector>

namespace audioshift
{
    namespace testing
    {
        namespace
        {

            // ── Helpers ───────────────────────────────────────────────────────────────────

            static float rmsOf(const std::vector<float> &v)
            {
                if (v.empty())
                    return 0.0f;
                double sq = 0.0;
                for (float s : v)
                    sq += static_cast<double>(s) * static_cast<double>(s);
                return static_cast<float>(std::sqrt(sq / static_cast<double>(v.size())));
            }

            // ── Test fixture ──────────────────────────────────────────────────────────────

            class SineGeneratorTest : public ::testing::Test
            {
            protected:
                static constexpr uint32_t kSampleRate = 48000;
                static constexpr uint32_t kFrames = 8192; // long window for FFT accuracy
                static constexpr float kAmp = 0.5f;
            };

            // ── Construction ──────────────────────────────────────────────────────────────

            TEST_F(SineGeneratorTest, ConstructsWithValidParams)
            {
                EXPECT_NO_THROW(SineGenerator(440.0f, kSampleRate, 1, kAmp));
                EXPECT_NO_THROW(SineGenerator(432.0f, kSampleRate, 2, 0.9f));
            }

            TEST_F(SineGeneratorTest, ThrowsOnZeroFrequency)
            {
                EXPECT_THROW(SineGenerator(0.0f, kSampleRate, 1, kAmp),
                             std::invalid_argument);
            }

            TEST_F(SineGeneratorTest, ThrowsOnNegativeFrequency)
            {
                EXPECT_THROW(SineGenerator(-100.0f, kSampleRate, 1, kAmp),
                             std::invalid_argument);
            }

            TEST_F(SineGeneratorTest, ThrowsOnNyquistExceeded)
            {
                // Nyquist = 24000 Hz; 24001 should throw.
                EXPECT_THROW(SineGenerator(24001.0f, kSampleRate, 1, kAmp),
                             std::invalid_argument);
            }

            TEST_F(SineGeneratorTest, ThrowsOnZeroSampleRate)
            {
                EXPECT_THROW(SineGenerator(440.0f, 0, 1, kAmp), std::invalid_argument);
            }

            TEST_F(SineGeneratorTest, ThrowsOnZeroChannels)
            {
                EXPECT_THROW(SineGenerator(440.0f, kSampleRate, 0, kAmp),
                             std::invalid_argument);
            }

            TEST_F(SineGeneratorTest, ThrowsOnAmplitudeOutOfRange)
            {
                EXPECT_THROW(SineGenerator(440.0f, kSampleRate, 1, 1.01f),
                             std::invalid_argument);
                EXPECT_THROW(SineGenerator(440.0f, kSampleRate, 1, -0.01f),
                             std::invalid_argument);
            }

            // ── Buffer length correctness ─────────────────────────────────────────────────

            TEST_F(SineGeneratorTest, MonoLengthCorrect)
            {
                SineGenerator gen(440.0f, kSampleRate, 1, kAmp);
                const auto buf = gen.generateFloat(kFrames);
                EXPECT_EQ(buf.size(), static_cast<std::size_t>(kFrames * 1));
            }

            TEST_F(SineGeneratorTest, StereoLengthCorrect)
            {
                SineGenerator gen(440.0f, kSampleRate, 2, kAmp);
                const auto buf = gen.generateFloat(kFrames);
                EXPECT_EQ(buf.size(), static_cast<std::size_t>(kFrames * 2));
            }

            TEST_F(SineGeneratorTest, Pcm16LengthMatchesFloat)
            {
                SineGenerator genF(440.0f, kSampleRate, 2, kAmp);
                SineGenerator genP(440.0f, kSampleRate, 2, kAmp);
                EXPECT_EQ(genF.generateFloat(kFrames).size(),
                          genP.generatePcm16(kFrames).size());
            }

            // ── Amplitude (RMS) ───────────────────────────────────────────────────────────

            TEST_F(SineGeneratorTest, RmsApproximatesExpected)
            {
                // For a sine of amplitude A, RMS = A / sqrt(2).
                const float amp = 0.5f;
                SineGenerator gen(440.0f, kSampleRate, 1, amp);
                const auto buf = gen.generateFloat(kFrames);

                const float rms = rmsOf(buf);
                const float expected = amp / std::sqrt(2.0f);
                // Allow 3% deviation (windowing edge effects on short buffers).
                EXPECT_NEAR(rms, expected, expected * 0.03f);
            }

            TEST_F(SineGeneratorTest, RmsScalesWithAmplitude)
            {
                SineGenerator gen1(440.0f, kSampleRate, 1, 0.25f);
                SineGenerator gen2(440.0f, kSampleRate, 1, 0.50f);

                const float rms1 = rmsOf(gen1.generateFloat(kFrames));
                const float rms2 = rmsOf(gen2.generateFloat(kFrames));

                // rms2 should be ~2× rms1.
                EXPECT_NEAR(rms2 / rms1, 2.0f, 0.05f);
            }

            // ── Sample range ──────────────────────────────────────────────────────────────

            TEST_F(SineGeneratorTest, FloatSamplesWithinRange)
            {
                SineGenerator gen(440.0f, kSampleRate, 2, kAmp);
                const auto buf = gen.generateFloat(kFrames);
                for (float s : buf)
                {
                    EXPECT_GE(s, -1.0f);
                    EXPECT_LE(s, 1.0f);
                }
            }

            TEST_F(SineGeneratorTest, Pcm16SamplesWithinRange)
            {
                SineGenerator gen(440.0f, kSampleRate, 2, kAmp);
                const auto buf = gen.generatePcm16(kFrames);
                for (int16_t s : buf)
                {
                    EXPECT_GE(s, static_cast<int16_t>(-32768));
                    EXPECT_LE(s, static_cast<int16_t>(32767));
                }
            }

            // ── Stereo layout ─────────────────────────────────────────────────────────────

            TEST_F(SineGeneratorTest, StereoChannelsAreIdentical)
            {
                // With mono-derived stereo both L and R should carry the same waveform.
                SineGenerator gen(440.0f, kSampleRate, 2, kAmp);
                const auto buf = gen.generateFloat(kFrames);

                for (std::size_t f = 0; f < kFrames; ++f)
                {
                    EXPECT_FLOAT_EQ(buf[f * 2 + 0], buf[f * 2 + 1])
                        << "Frame " << f << " has different L/R samples";
                }
            }

            // ── Frequency accuracy ────────────────────────────────────────────────────────

            TEST_F(SineGeneratorTest, Generates440Hz)
            {
                SineGenerator gen(440.0f, kSampleRate, 1, kAmp);
                const auto buf = gen.generateFloat(kFrames);
                // Mono buffer; detectFrequency expects mono float.
                EXPECT_TRUE(FrequencyValidator::isFrequency(buf, kSampleRate, 440.0f, 1.0f))
                    << "Detected frequency deviated from 440 Hz by > 1 Hz";
            }

            TEST_F(SineGeneratorTest, Generates432Hz)
            {
                SineGenerator gen(432.0f, kSampleRate, 1, kAmp);
                const auto buf = gen.generateFloat(kFrames);
                EXPECT_TRUE(FrequencyValidator::isFrequency(buf, kSampleRate, 432.0f, 1.0f))
                    << "Detected frequency deviated from 432 Hz by > 1 Hz";
            }

            TEST_F(SineGeneratorTest, Distinguishes440And432Hz)
            {
                SineGenerator gen440(440.0f, kSampleRate, 1, kAmp);
                const auto buf440 = gen440.generateFloat(kFrames);

                // A 440 Hz signal should NOT be accepted as 432 Hz within 1 Hz tolerance.
                EXPECT_FALSE(FrequencyValidator::isFrequency(buf440, kSampleRate, 432.0f, 1.0f))
                    << "440 Hz was incorrectly accepted as 432 Hz";
            }

            // ── Phase continuity across calls ─────────────────────────────────────────────

            TEST_F(SineGeneratorTest, PhaseContinuousAcrossCalls)
            {
                // Single large call vs. two equal halves — must produce identical output.
                const uint32_t half = kFrames / 2;

                SineGenerator genA(440.0f, kSampleRate, 1, kAmp);
                const auto fullBuf = genA.generateFloat(kFrames);

                SineGenerator genB(440.0f, kSampleRate, 1, kAmp);
                const auto part1 = genB.generateFloat(half);
                const auto part2 = genB.generateFloat(half);

                for (std::size_t i = 0; i < half; ++i)
                {
                    EXPECT_FLOAT_EQ(fullBuf[i], part1[i]);
                    EXPECT_FLOAT_EQ(fullBuf[i + half], part2[i]);
                }
            }

            // ── resetPhase ────────────────────────────────────────────────────────────────

            TEST_F(SineGeneratorTest, ResetPhaseRestartsFromZero)
            {
                SineGenerator gen(440.0f, kSampleRate, 1, kAmp);
                const auto first = gen.generateFloat(kFrames);

                gen.resetPhase();
                const auto second = gen.generateFloat(kFrames);

                // After reset, output should be identical to the first call.
                for (std::size_t i = 0; i < kFrames; ++i)
                {
                    EXPECT_FLOAT_EQ(first[i], second[i]);
                }
            }

            // ── setFrequency ──────────────────────────────────────────────────────────────

            TEST_F(SineGeneratorTest, SetFrequencyChangesDetectedPitch)
            {
                SineGenerator gen(440.0f, kSampleRate, 1, kAmp);

                gen.setFrequency(880.0f);
                const auto buf = gen.generateFloat(kFrames);

                EXPECT_TRUE(FrequencyValidator::isFrequency(buf, kSampleRate, 880.0f, 2.0f))
                    << "After setFrequency(880), detected pitch not near 880 Hz";
            }

            // ── Zero return on zero frames ────────────────────────────────────────────────

            TEST_F(SineGeneratorTest, ZeroFramesReturnsEmptyBuffer)
            {
                SineGenerator gen(440.0f, kSampleRate, 1, kAmp);
                EXPECT_TRUE(gen.generateFloat(0).empty());
                EXPECT_TRUE(gen.generatePcm16(0).empty());
            }

        } // namespace
    } // namespace testing
} // namespace audioshift
