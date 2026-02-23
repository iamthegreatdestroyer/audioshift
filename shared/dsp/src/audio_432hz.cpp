#include "audio_432hz.h"
#include <SoundTouch.h>
#include <vector>
#include <cmath>
#include <algorithm>
#include <chrono>

namespace audioshift {
namespace dsp {

// Pimpl implementation using SoundTouch
class Audio432HzConverter::Impl {
public:
    soundtouch::SoundTouch soundTouch;
    int sampleRate;
    int channels;
    std::vector<float> floatIn;
    std::vector<float> floatOut;
    std::atomic<float> cpuUsage{0.0f};
    std::chrono::steady_clock::time_point lastProcessTime;

    // Pitch shift value: 432/440 = 0.98182 = -31.77 cents ≈ -0.5296 semitones
    static constexpr float PITCH_SEMITONES = -0.5296f;

    Impl(int sr, int ch) : sampleRate(sr), channels(ch) {
        soundTouch.setSampleRate(sr);
        soundTouch.setChannels(ch);
        soundTouch.setPitchSemiTones(PITCH_SEMITONES);

        // Tuning for real-time: lower latency, reasonable quality
        soundTouch.setSetting(soundtouch::SoundTouch::SETTING_USE_AA_FILTER, 1);
        soundTouch.setSetting(soundtouch::SoundTouch::SETTING_SEQUENCE_MS, 40);
        soundTouch.setSetting(soundtouch::SoundTouch::SETTING_SEEKWINDOW_MS, 15);
        soundTouch.setSetting(soundtouch::SoundTouch::SETTING_OVERLAP_MS, 8);

        lastProcessTime = std::chrono::steady_clock::now();
    }
};

Audio432HzConverter::Audio432HzConverter(int sampleRate, int channels)
    : pImpl_(std::make_unique<Impl>(sampleRate, channels)) {
}

Audio432HzConverter::~Audio432HzConverter() = default;

int Audio432HzConverter::process(int16_t* buffer, int numSamples) {
    if (!buffer || numSamples <= 0 || !pImpl_) {
        return 0;
    }

    auto t0 = std::chrono::steady_clock::now();

    // Resize staging buffers to avoid repeated allocations
    uint32_t totalSamples = numSamples;
    if (pImpl_->floatIn.size() < totalSamples) {
        pImpl_->floatIn.resize(totalSamples);
        pImpl_->floatOut.resize(totalSamples * 2);  // extra headroom for output
    }

    // Convert int16 to float
    for (int i = 0; i < numSamples; i++) {
        pImpl_->floatIn[i] = buffer[i] / 32768.0f;
    }

    // Process through SoundTouch
    pImpl_->soundTouch.putSamples(pImpl_->floatIn.data(), numSamples / pImpl_->channels);

    // Receive processed samples
    uint32_t received = pImpl_->soundTouch.receiveSamples(
        pImpl_->floatOut.data(),
        std::min((uint32_t)pImpl_->floatOut.size(), (uint32_t)(numSamples * 2))
    );

    // Convert back to int16, handle silence for startup latency
    uint32_t outputSamples = std::min(received, (uint32_t)numSamples);
    for (uint32_t i = 0; i < outputSamples; i++) {
        float sample = pImpl_->floatOut[i] * 32767.0f;
        sample = std::max(-32768.0f, std::min(32767.0f, sample));
        buffer[i] = (int16_t)sample;
    }

    // Zero-fill remainder if fewer samples returned (startup latency)
    for (uint32_t i = outputSamples; i < numSamples; i++) {
        buffer[i] = 0;
    }

    // Update CPU usage estimation
    auto t1 = std::chrono::steady_clock::now();
    auto elapsedUs = std::chrono::duration_cast<std::chrono::microseconds>(t1 - t0).count();
    auto audioTimeUs = (numSamples * 1e6) / pImpl_->sampleRate;
    pImpl_->cpuUsage.store(100.0f * elapsedUs / audioTimeUs, std::memory_order_relaxed);

    return numSamples;
}

void Audio432HzConverter::setSampleRate(int sampleRate) {
    if (pImpl_) {
        pImpl_->sampleRate = sampleRate;
        pImpl_->soundTouch.setSampleRate(sampleRate);
        pImpl_->soundTouch.clear();
    }
}

void Audio432HzConverter::setPitchShiftSemitones(float semitones) {
    if (pImpl_) {
        pImpl_->soundTouch.setPitchSemiTones(semitones);
    }
}

float Audio432HzConverter::getLatencyMs() const {
    if (!pImpl_) return 0.0f;
    // Latency = (sequenceMs/2 + seekwindowMs + overlapMs) * sample rate independent estimate
    // Approximate: 40ms/2 + 15ms + 8ms ≈ 35ms + network buffering
    return 35.0f;
}

float Audio432HzConverter::getCpuUsagePercent() const {
    if (!pImpl_) return 0.0f;
    return pImpl_->cpuUsage.load(std::memory_order_relaxed);
}

}  // namespace dsp
}  // namespace audioshift
