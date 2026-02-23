/**
 * sine_generator.cpp
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include "sine_generator.h"

#include <cmath>
#include <numbers> // std::numbers::pi_v  (C++20; see fallback below)
#include <stdexcept>
#include <algorithm>

namespace audioshift
{
    namespace testing
    {

        // ── Constants ────────────────────────────────────────────────────────────────

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

        static constexpr double kTwoPi = 2.0 * M_PI;

        // ── Construction ─────────────────────────────────────────────────────────────

        SineGenerator::SineGenerator(float frequencyHz,
                                     uint32_t sampleRate,
                                     uint32_t channels,
                                     float amplitudeFs)
            : frequencyHz_(frequencyHz),
              sampleRate_(sampleRate),
              channels_(channels),
              amplitudeFs_(amplitudeFs),
              phaseRad_(0.0),
              phaseIncrement_(kTwoPi * static_cast<double>(frequencyHz) /
                              static_cast<double>(sampleRate))
        {
            if (frequencyHz <= 0.0f)
            {
                throw std::invalid_argument("SineGenerator: frequencyHz must be > 0");
            }
            if (sampleRate == 0)
            {
                throw std::invalid_argument("SineGenerator: sampleRate must be > 0");
            }
            if (channels == 0 || channels > 8)
            {
                throw std::invalid_argument("SineGenerator: channels must be in [1, 8]");
            }
            if (amplitudeFs < 0.0f || amplitudeFs > 1.0f)
            {
                throw std::invalid_argument("SineGenerator: amplitudeFs must be in [0, 1]");
            }
            if (frequencyHz >= static_cast<float>(sampleRate) / 2.0f)
            {
                throw std::invalid_argument(
                    "SineGenerator: frequencyHz must be < sampleRate/2 (Nyquist)");
            }
        }

        // ── setFrequency ──────────────────────────────────────────────────────────────

        void SineGenerator::setFrequency(float newFrequencyHz) noexcept
        {
            frequencyHz_ = newFrequencyHz;
            phaseIncrement_ = kTwoPi * static_cast<double>(newFrequencyHz) /
                              static_cast<double>(sampleRate_);
        }

        // ── generateFloat ─────────────────────────────────────────────────────────────

        std::vector<float> SineGenerator::generateFloat(uint32_t frames)
        {
            const std::size_t totalSamples =
                static_cast<std::size_t>(frames) * channels_;
            std::vector<float> out(totalSamples);

            const double amp = static_cast<double>(amplitudeFs_);

            for (uint32_t f = 0; f < frames; ++f)
            {
                const float sample = static_cast<float>(amp * std::sin(phaseRad_));

                // Advance phase accumulator.
                phaseRad_ += phaseIncrement_;

                // Wrap to [-π, π] to prevent precision loss for long signals.
                // Using fmod is slower but avoids drift over millions of frames.
                if (phaseRad_ >= M_PI)
                {
                    phaseRad_ -= kTwoPi;
                }

                // Write the same sample to all channels (mono-derived stereo / multi).
                for (uint32_t ch = 0; ch < channels_; ++ch)
                {
                    out[f * channels_ + ch] = sample;
                }
            }

            return out;
        }

        // ── generatePcm16 ─────────────────────────────────────────────────────────────

        std::vector<int16_t> SineGenerator::generatePcm16(uint32_t frames)
        {
            const auto floatBuf = generateFloat(frames);

            std::vector<int16_t> out(floatBuf.size());
            for (std::size_t i = 0; i < floatBuf.size(); ++i)
            {
                // Scale and clamp to int16_t range, matching pcm16ToFloat convention.
                float scaled = floatBuf[i] * 32767.0f;
                scaled = std::clamp(scaled, -32768.0f, 32767.0f);
                out[i] = static_cast<int16_t>(scaled);
            }
            return out;
        }

    } // namespace testing
} // namespace audioshift
