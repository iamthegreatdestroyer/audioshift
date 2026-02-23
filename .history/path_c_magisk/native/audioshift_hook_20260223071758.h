/**
 * AudioShift PATH-C — Hook Library Header
 *
 * Android Audio Effect API implementation that performs real-time
 * pitch conversion from 440 Hz to 432 Hz tuning standard.
 *
 * Implementation Strategy:
 *   - Registers as an Android audio effect via the Effects API
 *   - AudioFlinger loads the library for all audio output tracks
 *   - WSOLA pitch-shift (SoundTouch) applied in the process callback
 *
 * Architecture reference: docs/ANDROID_INTERNALS.md
 */

#pragma once

#include <cstdint>
#include <cstring>
#include <memory>
#include <android/log.h>

// Android Audio Effects API
// <hardware/audio_effect.h> provides effect_interface_s and related structs
#include <hardware/audio_effect.h>

#define LOG_TAG "AudioShift"
#define ASHIFT_LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define ASHIFT_LOGW(...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, __VA_ARGS__)
#define ASHIFT_LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#define ASHIFT_LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)

namespace audioshift
{

    // ─── Constants ────────────────────────────────────────────────────────────────

    /**
     * Pitch ratio: 432 / 440 = 0.981818...
     * Semitones:   12 * log2(432/440) ≈ -0.3164 semitones
     */
    constexpr float PITCH_RATIO_432_HZ = 432.0f / 440.0f;
    constexpr float PITCH_SEMITONES_432_HZ = -0.3164f; // Pre-computed

    /** Default DSP parameters */
    constexpr int DEFAULT_SAMPLE_RATE = 48000;
    constexpr int DEFAULT_CHANNELS = 2;
    constexpr int MAX_FRAME_SIZE = 8192; // samples per channel
    constexpr float MAX_LATENCY_MS = 20.0f;

    // ─── Effect UUID ──────────────────────────────────────────────────────────────

    /** AudioShift effect type UUID (custom; must match audio_effects_audioshift.xml) */
    static const effect_uuid_t AUDIOSHIFT_EFFECT_TYPE_UUID = {
        0x7b491460, 0x8d4d, 0x11e0, 0xbd6a, {0x00, 0x02, 0xa5, 0xd5, 0xc5, 0x1b}};

    /** AudioShift effect implementation UUID */
    static const effect_uuid_t AUDIOSHIFT_EFFECT_IMPL_UUID = {
        0xf1a2b3c4, 0x5678, 0x90ab, 0xcdef, {0x01, 0x23, 0x45, 0x67, 0x89, 0xab}};

    // ─── Effect Descriptor ────────────────────────────────────────────────────────

    static const effect_descriptor_t AUDIOSHIFT_EFFECT_DESCRIPTOR = {
        AUDIOSHIFT_EFFECT_TYPE_UUID, // type
        AUDIOSHIFT_EFFECT_IMPL_UUID, // uuid
        EFFECT_CONTROL_API_VERSION,  // apiVersion
        (EFFECT_FLAG_TYPE_INSERT | EFFECT_FLAG_INSERT_LAST |
         EFFECT_FLAG_DEVICE_IND | EFFECT_FLAG_AUDIO_MODE_IND), // flags
        500,                                                   // cpuLoad (0.5% in MIPS tenths)
        32,                                                    // memoryUsage (KB)
        "AudioShift 432Hz Converter",                          // name
        "AudioShift Project"                                   // implementor
    };

    // ─── Parameter Commands ───────────────────────────────────────────────────────

    /** Custom effect commands (EFFECT_CMD_FIRST_PROPRIETARY + N) */
    enum AudioShiftCommand : uint32_t
    {
        CMD_SET_ENABLED = EFFECT_CMD_FIRST_PROPRIETARY,         // enable/disable
        CMD_SET_PITCH_RATIO = EFFECT_CMD_FIRST_PROPRIETARY + 1, // float ratio
        CMD_GET_LATENCY_MS = EFFECT_CMD_FIRST_PROPRIETARY + 2,  // float ms (reply)
        CMD_GET_CPU_USAGE = EFFECT_CMD_FIRST_PROPRIETARY + 3,   // float % (reply)
        CMD_RESET_STATS = EFFECT_CMD_FIRST_PROPRIETARY + 4,
    };

    // ─── Effect Context ───────────────────────────────────────────────────────────

    /**
     * Per-instance state maintained by the effect engine.
     * The first member MUST be effect_handle_t (Android requirement).
     */
    struct AudioShiftContext
    {
        const struct effect_interface_s *itfe; // MUST be first — cast compatibility

        // Configuration
        audio_config_t config;
        bool enabled;
        float pitchSemitones;

        // SoundTouch DSP backend (opaque pointer avoids direct SoundTouch dependency
        // in this header — forward-declared and heap-allocated in the .cpp)
        void *soundtouch;

        // Scratch buffer for float32 conversion
        float floatBuf[MAX_FRAME_SIZE * DEFAULT_CHANNELS];

        // Stats (sampled on each process() call)
        float lastLatencyMs;
        float lastCpuPercent;
        uint64_t frameCount;
    };

    // ─── C API (exported symbols) ─────────────────────────────────────────────────

    extern "C"
    {

        /**
         * Required entry points for Android Audio Effects API.
         * Declared with visibility("default") so the dynamic linker can find them.
         */
        __attribute__((visibility("default"))) int EffectCreate(const effect_uuid_t *uuid,
                                                                int32_t sessionId,
                                                                int32_t ioId,
                                                                effect_handle_t *pHandle);

        __attribute__((visibility("default"))) int EffectRelease(effect_handle_t handle);

        __attribute__((visibility("default"))) int EffectGetDescriptor(const effect_uuid_t *uuid,
                                                                       effect_descriptor_t *pDescriptor);

        __attribute__((visibility("default"))) int EffectQueryNumberEffects(uint32_t *pNumEffects);

        __attribute__((visibility("default"))) int EffectQueryEffect(uint32_t index, effect_descriptor_t *pDescriptor);

    } // extern "C"

} // namespace audioshift
