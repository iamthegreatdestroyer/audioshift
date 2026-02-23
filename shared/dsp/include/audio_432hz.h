#ifndef AUDIOSHIFT_AUDIO_432HZ_H
#define AUDIOSHIFT_AUDIO_432HZ_H

#include <cstdint>
#include <memory>

namespace audioshift {
namespace dsp {

/**
 * @brief Real-time audio pitch-shift to 432 Hz tuning frequency
 *
 * Converts audio from 440 Hz tuning (A4=440) to 432 Hz tuning (A4=432)
 * using WSOLA (Waveform Similarity Overlap-Add) algorithm.
 *
 * Conversion ratio: 432/440 ≈ 0.98182 (-31.77 cents)
 *
 * @note This class is thread-safe for single-consumer usage.
 * @note Designed for real-time audio processing with minimal latency.
 */
class Audio432HzConverter {
public:
    /**
     * @brief Initialize converter
     * @param sampleRate Audio sample rate (Hz) - typically 48000
     * @param channels Number of audio channels (1=mono, 2=stereo)
     */
    Audio432HzConverter(int sampleRate = 48000, int channels = 2);

    ~Audio432HzConverter();

    /**
     * @brief Process audio buffer to 432 Hz pitch
     * @param buffer Input/output PCM audio buffer (int16 samples)
     * @param numSamples Number of samples in buffer
     * @return Actual samples processed
     */
    int process(int16_t* buffer, int numSamples);

    /**
     * @brief Set sample rate (may reset internal state)
     * @param sampleRate New sample rate in Hz
     */
    void setSampleRate(int sampleRate);

    /**
     * @brief Set pitch shift amount in semitones
     * @param semitones Pitch shift (-0.53 for 432 Hz conversion)
     */
    void setPitchShiftSemitones(float semitones);

    /**
     * @brief Get estimated latency from input to output
     * @return Latency in milliseconds
     */
    float getLatencyMs() const;

    /**
     * @brief Get estimated CPU usage
     * @return CPU usage percentage (0.0-100.0)
     */
    float getCpuUsagePercent() const;

private:
    class Impl;  // Pimpl pattern for hiding SoundTouch dependency
    std::unique_ptr<Impl> pImpl_;
};

}  // namespace dsp
}  // namespace audioshift

#endif  // AUDIOSHIFT_AUDIO_432HZ_H
