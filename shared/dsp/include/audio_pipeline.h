#ifndef AUDIOSHIFT_AUDIO_PIPELINE_H
#define AUDIOSHIFT_AUDIO_PIPELINE_H

#include "audio_432hz.h"
#include <memory>
#include <atomic>
#include <mutex>
#include <cstdint>

namespace audioshift {
namespace dsp {

/// Statistics from the audio pipeline
struct PipelineStats {
    float latencyMs = 0.0f;
    float cpuPercent = 0.0f;
    uint64_t framesProcessed = 0;
    uint64_t framesDropped = 0;
};

/// Thread-safe audio processing pipeline singleton
/// Used by PATH-C LD_PRELOAD hook to access converter from hook context
class AudioPipeline {
public:
    /// Get singleton instance
    static AudioPipeline& getInstance();

    /// Initialize pipeline with sample rate and channels
    void initialize(int sampleRate, int channels);

    /// Shutdown and cleanup
    void shutdown();

    /// Process buffer in-place (returns false if pipeline not ready)
    bool processInPlace(int16_t* buffer, int numFrames);

    /// Enable/disable audio processing
    void setEnabled(bool enabled);
    bool isEnabled() const;

    /// Get current pipeline statistics
    PipelineStats getStats() const;

    /// Reset statistics
    void resetStats();

private:
    AudioPipeline() = default;
    ~AudioPipeline() = default;

    // No copy/move
    AudioPipeline(const AudioPipeline&) = delete;
    AudioPipeline& operator=(const AudioPipeline&) = delete;

    std::unique_ptr<Audio432HzConverter> converter_;
    std::atomic<bool> enabled_{false};
    std::atomic<bool> initialized_{false};
    std::mutex initMutex_;

    std::atomic<uint64_t> framesProcessed_{0};
    std::atomic<uint64_t> framesDropped_{0};
};

}  // namespace dsp
}  // namespace audioshift

#endif  // AUDIOSHIFT_AUDIO_PIPELINE_H
