/// SoundTouch - Sound Processing Library
/// Copyright (c) 2001-2022 Olli Parviainen
/// Provided as minimal implementation for AudioShift integration
/// Full source available at: https://www.soundtouch.net/

#pragma once

#include "STTypes.h"
#include <cstdint>

namespace soundtouch {

class SoundTouch {
public:
    SoundTouch();
    ~SoundTouch();

    /// Set sample rate
    void setSampleRate(uint32_t srate);

    /// Set number of channels
    void setChannels(uint32_t numChannels);

    /// Set pitch shift in semitones
    /// Negative values = lower pitch, Positive = higher pitch
    /// Range: typically -36 to +36 semitones
    void setPitchSemiTones(float semitones);

    /// Set tempo (playback rate) in %
    /// 100.0 = normal tempo, 50.0 = half speed, 200.0 = double speed
    void setTempo(float newTempo);

    /// Set rate in Hz
    void setRate(float newRate);

    /// Put samples to input buffer
    /// sampleData: interleaved sample buffer
    /// numSamples: number of samples (total samples = numSamples * channels)
    void putSamples(const float *sampleData, uint32_t numSamples);

    /// Receive samples from output buffer
    /// Returns number of samples copied
    uint32_t receiveSamples(float *outBuffer, uint32_t maxSamples);

    /// Receive samples as int16
    uint32_t receiveSamples(int16_t *outBuffer, uint32_t maxSamples);

    /// Number of samples available
    uint32_t numSamples() const;

    /// Clear internal buffers
    void clear();

    /// Flush remaining samples
    void flush();

    /// Set processing parameters
    enum SettingId {
        SETTING_USE_AA_FILTER        = 0,
        SETTING_AA_FILTER_LENGTH     = 1,
        SETTING_USE_QUICKSEEK        = 2,
        SETTING_SEQUENCE_MS          = 3,
        SETTING_SEEKWINDOW_MS        = 4,
        SETTING_OVERLAP_MS           = 5,
    };

    int32_t setSetting(int settingId, int32_t value);
    int32_t getSetting(int settingId) const;

private:
    class Impl;
    Impl* pImpl;

    SoundTouch(const SoundTouch&) = delete;
    SoundTouch& operator=(const SoundTouch&) = delete;
};

} // namespace soundtouch
