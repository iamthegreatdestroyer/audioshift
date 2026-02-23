/// SoundTouch - Sound Processing Library
/// Simplified WSOLA-based pitch shift implementation for AudioShift

#include <SoundTouch.h>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <vector>
#include <deque>

namespace soundtouch {

// WSOLA window coefficients (Hann window)
class HannWindow {
public:
    static float coeff(int i, int windowLen) {
        // Hann window: 0.5 * (1 - cos(2*pi*i/(N-1)))
        return 0.5f * (1.0f - cosf(2.0f * 3.14159265f * i / (windowLen - 1)));
    }
};

class SoundTouch::Impl {
public:
    uint32_t sampleRate = 48000;
    uint32_t channels = 2;
    float pitchSemitones = 0.0f;
    float tempo = 1.0f;
    float rate = 1.0f;

    // WSOLA parameters
    int32_t sequenceMs = 40;
    int32_t seekwindowMs = 15;
    int32_t overlapMs = 8;

    // Derived parameters
    uint32_t sequenceSamples = 0;
    uint32_t seekwindowSamples = 0;
    uint32_t overlapSamples = 0;

    // Input and output buffers
    std::deque<float> inputBuffer;
    std::deque<float> outputBuffer;

    // Processing state
    uint32_t inputPosition = 0;

    Impl() {
        updateSampleCounts();
    }

    void updateSampleCounts() {
        sequenceSamples = (uint32_t)(sampleRate * sequenceMs / 1000.0f);
        seekwindowSamples = (uint32_t)(sampleRate * seekwindowMs / 1000.0f);
        overlapSamples = (uint32_t)(sampleRate * overlapMs / 1000.0f);
    }

    float pitchRatioFromSemitones(float semitones) const {
        // pitchRatio = 2^(semitones/12)
        return powf(2.0f, semitones / 12.0f);
    }

    float findBestOverlapOffset() {
        // Simplified overlap detection using correlation
        // Returns the offset in samples that gives best correlation
        if (seekwindowSamples == 0) return 0;

        float bestCorrelation = -1e6f;
        uint32_t bestOffset = 0;

        uint32_t referenceStart = inputPosition;
        uint32_t searchStart = std::max(0U, referenceStart - seekwindowSamples);

        for (uint32_t offset = searchStart; offset < referenceStart && offset + overlapSamples < inputBuffer.size(); offset += 1) {
            float correlation = 0.0f;
            for (uint32_t i = 0; i < overlapSamples; i++) {
                if (referenceStart + i < inputBuffer.size() && offset + i < inputBuffer.size()) {
                    correlation += inputBuffer[referenceStart + i] * inputBuffer[offset + i];
                }
            }
            if (correlation > bestCorrelation) {
                bestCorrelation = correlation;
                bestOffset = offset;
            }
        }

        return (float)bestOffset;
    }

    void processFrame() {
        if (inputBuffer.size() < sequenceSamples * channels) {
            return;  // Not enough samples
        }

        float pitchRatio = pitchRatioFromSemitones(pitchSemitones);
        float effectiveRate = rate * tempo / pitchRatio;

        // Extract processing frame
        std::vector<float> frame(sequenceSamples * channels);
        for (size_t i = 0; i < frame.size(); i++) {
            frame[i] = inputBuffer[i];
        }

        // Apply windowing to current frame
        for (uint32_t ch = 0; ch < channels; ch++) {
            for (uint32_t i = 0; i < sequenceSamples; i++) {
                float window = HannWindow::coeff(i, sequenceSamples);
                frame[i * channels + ch] *= window;
            }
        }

        // Find best overlap position from history
        float overlapOffset = findBestOverlapOffset();

        // Apply overlap-add with previous frame
        if (inputPosition > 0 && overlapSamples > 0) {
            for (uint32_t ch = 0; ch < channels; ch++) {
                for (uint32_t i = 0; i < overlapSamples && i < frame.size(); i++) {
                    float fadeIn = (float)i / overlapSamples;
                    float fadeOut = 1.0f - fadeIn;
                    uint32_t historyIdx = (uint32_t)overlapOffset * channels + ch;
                    if (historyIdx + i * channels < inputBuffer.size()) {
                        frame[i * channels + ch] = fadeOut * inputBuffer[historyIdx + i * channels] +
                                                   fadeIn * frame[i * channels + ch];
                    }
                }
            }
        }

        // Output frame
        for (const auto& sample : frame) {
            outputBuffer.push_back(sample);
        }

        // Advance input position
        uint32_t advanceSamples = (uint32_t)(sequenceSamples * effectiveRate);
        for (uint32_t i = 0; i < advanceSamples * channels && !inputBuffer.empty(); i++) {
            inputBuffer.pop_front();
        }

        inputPosition = 0;
    }
};

SoundTouch::SoundTouch() : pImpl(new Impl()) {
}

SoundTouch::~SoundTouch() {
    delete pImpl;
}

void SoundTouch::setSampleRate(uint32_t srate) {
    pImpl->sampleRate = srate;
    pImpl->updateSampleCounts();
}

void SoundTouch::setChannels(uint32_t numChannels) {
    pImpl->channels = numChannels;
}

void SoundTouch::setPitchSemiTones(float semitones) {
    pImpl->pitchSemitones = semitones;
}

void SoundTouch::setTempo(float newTempo) {
    pImpl->tempo = newTempo;
}

void SoundTouch::setRate(float newRate) {
    pImpl->rate = newRate;
}

void SoundTouch::putSamples(const float *sampleData, uint32_t numSamples) {
    if (!sampleData || numSamples == 0) return;

    uint32_t totalSamples = numSamples * pImpl->channels;
    for (uint32_t i = 0; i < totalSamples; i++) {
        pImpl->inputBuffer.push_back(sampleData[i]);
    }

    // Process available frames
    while (pImpl->inputBuffer.size() >= pImpl->sequenceSamples * pImpl->channels) {
        pImpl->processFrame();
    }
}

uint32_t SoundTouch::receiveSamples(float *outBuffer, uint32_t maxSamples) {
    if (!outBuffer || maxSamples == 0) return 0;

    uint32_t available = std::min((uint32_t)pImpl->outputBuffer.size(), maxSamples);
    for (uint32_t i = 0; i < available; i++) {
        outBuffer[i] = pImpl->outputBuffer.front();
        pImpl->outputBuffer.pop_front();
    }

    return available;
}

uint32_t SoundTouch::receiveSamples(int16_t *outBuffer, uint32_t maxSamples) {
    if (!outBuffer || maxSamples == 0) return 0;

    std::vector<float> temp(maxSamples);
    uint32_t received = receiveSamples(temp.data(), maxSamples);

    // Convert float to int16
    for (uint32_t i = 0; i < received; i++) {
        float sample = temp[i] * 32767.0f;
        sample = std::max(-32768.0f, std::min(32767.0f, sample));
        outBuffer[i] = (int16_t)sample;
    }

    return received;
}

uint32_t SoundTouch::numSamples() const {
    return pImpl->outputBuffer.size();
}

void SoundTouch::clear() {
    pImpl->inputBuffer.clear();
    pImpl->outputBuffer.clear();
    pImpl->inputPosition = 0;
}

void SoundTouch::flush() {
    // Process any remaining samples
    while (!pImpl->inputBuffer.empty()) {
        pImpl->processFrame();
    }
}

int32_t SoundTouch::setSetting(int settingId, int32_t value) {
    switch (settingId) {
        case SETTING_USE_AA_FILTER:
            // Anti-alias filter flag - not used in simplified implementation
            break;
        case SETTING_AA_FILTER_LENGTH:
            // Anti-alias filter length
            break;
        case SETTING_USE_QUICKSEEK:
            // Quick seek flag
            break;
        case SETTING_SEQUENCE_MS:
            pImpl->sequenceMs = value;
            pImpl->updateSampleCounts();
            break;
        case SETTING_SEEKWINDOW_MS:
            pImpl->seekwindowMs = value;
            pImpl->updateSampleCounts();
            break;
        case SETTING_OVERLAP_MS:
            pImpl->overlapMs = value;
            pImpl->updateSampleCounts();
            break;
    }
    return 0;
}

int32_t SoundTouch::getSetting(int settingId) const {
    switch (settingId) {
        case SETTING_SEQUENCE_MS:
            return pImpl->sequenceMs;
        case SETTING_SEEKWINDOW_MS:
            return pImpl->seekwindowMs;
        case SETTING_OVERLAP_MS:
            return pImpl->overlapMs;
    }
    return 0;
}

} // namespace soundtouch
