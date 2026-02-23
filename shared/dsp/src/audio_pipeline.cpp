#include "audio_pipeline.h"
#include <mutex>

namespace audioshift {
namespace dsp {

AudioPipeline& AudioPipeline::getInstance() {
    static AudioPipeline instance;
    return instance;
}

void AudioPipeline::initialize(int sampleRate, int channels) {
    std::lock_guard<std::mutex> lock(initMutex_);

    if (initialized_.load(std::memory_order_acquire)) {
        return;  // Already initialized
    }

    converter_ = std::make_unique<Audio432HzConverter>(sampleRate, channels);
    initialized_.store(true, std::memory_order_release);
}

void AudioPipeline::shutdown() {
    std::lock_guard<std::mutex> lock(initMutex_);
    converter_.reset();
    initialized_.store(false, std::memory_order_release);
}

bool AudioPipeline::processInPlace(int16_t* buffer, int numFrames) {
    if (!buffer || numFrames <= 0) {
        return false;
    }

    if (!enabled_.load(std::memory_order_acquire) ||
        !initialized_.load(std::memory_order_acquire)) {
        return false;
    }

    if (!converter_) {
        return false;
    }

    int result = converter_->process(buffer, numFrames);
    framesProcessed_.fetch_add(numFrames, std::memory_order_relaxed);

    if (result != numFrames) {
        framesDropped_.fetch_add(numFrames - result, std::memory_order_relaxed);
    }

    return true;
}

void AudioPipeline::setEnabled(bool enabled) {
    enabled_.store(enabled, std::memory_order_release);
}

bool AudioPipeline::isEnabled() const {
    return enabled_.load(std::memory_order_acquire);
}

PipelineStats AudioPipeline::getStats() const {
    PipelineStats stats;
    stats.framesProcessed = framesProcessed_.load(std::memory_order_acquire);
    stats.framesDropped = framesDropped_.load(std::memory_order_acquire);

    if (converter_) {
        stats.latencyMs = converter_->getLatencyMs();
        stats.cpuPercent = converter_->getCpuUsagePercent();
    }

    return stats;
}

void AudioPipeline::resetStats() {
    framesProcessed_.store(0, std::memory_order_release);
    framesDropped_.store(0, std::memory_order_release);
}

}  // namespace dsp
}  // namespace audioshift
