/**
 * AudioShift PATH-C — Audio Effect Implementation
 *
 * Implements the Android Audio Effects API to register AudioShift as a
 * system-level audio effect processed by AudioFlinger.
 *
 * Signal flow:
 *   AudioFlinger output buffer
 *       → EffectProcess() [int16_t PCM in]
 *       → int16_t→float32 conversion
 *       → SoundTouch WSOLA pitch-shift (432/440 ratio)
 *       → float32→int16_t conversion
 *       → AudioFlinger continues to HAL
 *
 * Threading: AudioFlinger calls process() on its mixer thread.
 *            All SoundTouch access is single-threaded per-instance,
 *            so no locking is needed inside process().
 *
 * Reference: docs/ANDROID_INTERNALS.md §4 "Audio Effects Framework"
 */

#include "audioshift_hook.h"

#include <cmath>
#include <cstdlib>
#include <cstring>
#include <new>
#include <time.h>

// SoundTouch from shared DSP layer
// When cross-compiled for Android, the NDK build links against
// the static soundtouch_internal built by path_c_magisk/native/CMakeLists.txt
#include "SoundTouch.h"

using soundtouch::SoundTouch;

// ─── Internal helpers ─────────────────────────────────────────────────────────

namespace
{

    /** Monotonic wall-clock in milliseconds. */
    static inline double nowMs()
    {
        struct timespec ts;
        clock_gettime(CLOCK_MONOTONIC, &ts);
        return static_cast<double>(ts.tv_sec) * 1000.0 +
               static_cast<double>(ts.tv_nsec) / 1.0e6;
    }

    /**
     * Convert signed 16-bit PCM → float32 in [-1, +1].
     * Handles interleaved stereo (channels=2) or mono (channels=1).
     */
    static void pcm16ToFloat(const int16_t *src, float *dst, int frames, int channels)
    {
        const int samples = frames * channels;
        const float kScale = 1.0f / 32768.0f;
        for (int i = 0; i < samples; ++i)
        {
            dst[i] = static_cast<float>(src[i]) * kScale;
        }
    }

    /**
     * Convert float32 in [-1, +1] → signed 16-bit PCM with clamping.
     */
    static void floatToPcm16(const float *src, int16_t *dst, int frames, int channels)
    {
        const int samples = frames * channels;
        for (int i = 0; i < samples; ++i)
        {
            float v = src[i] * 32768.0f;
            if (v > 32767.0f)
                v = 32767.0f;
            else if (v < -32768.0f)
                v = -32768.0f;
            dst[i] = static_cast<int16_t>(v);
        }
    }

    // ─── Effect interface function table (forward declarations) ───────────────────

    static int effectProcess(effect_handle_t self, audio_buffer_t *in, audio_buffer_t *out);
    static int effectCommand(effect_handle_t self, uint32_t cmdCode,
                             uint32_t cmdSize, void *pCmdData,
                             uint32_t *replySize, void *pReplyData);
    static int effectGetDescriptor(effect_handle_t self, effect_descriptor_t *pDescriptor);
    static int effectProcessReverse(effect_handle_t self, audio_buffer_t *in, audio_buffer_t *out);

    /** Static interface vtable — all AudioShift instances share this. */
    static const struct effect_interface_s kEffectInterface = {
        effectProcess,
        effectCommand,
        effectGetDescriptor,
        effectProcessReverse,
    };

} // anonymous namespace

// ─── Effect life-cycle ────────────────────────────────────────────────────────

extern "C" int EffectCreate(const effect_uuid_t *uuid,
                            int32_t /*sessionId*/,
                            int32_t /*ioId*/,
                            effect_handle_t *pHandle)
{
    if (!uuid || !pHandle)
        return -EINVAL;

    if (memcmp(uuid, &audioshift::AUDIOSHIFT_EFFECT_IMPL_UUID, sizeof(*uuid)) != 0)
    {
        ASHIFT_LOGE("EffectCreate: unknown UUID");
        return -EINVAL;
    }

    audioshift::AudioShiftContext *ctx =
        new (std::nothrow) audioshift::AudioShiftContext();
    if (!ctx)
        return -ENOMEM;

    ctx->itfe = &kEffectInterface;
    ctx->enabled = false;
    ctx->pitchSemitones = audioshift::PITCH_SEMITONES_432_HZ;
    ctx->lastLatencyMs = 0.0f;
    ctx->lastCpuPercent = 0.0f;
    ctx->frameCount = 0;

    // Default config: 48 kHz stereo (Android standard)
    memset(&ctx->config, 0, sizeof(ctx->config));
    ctx->config.inputCfg.accessMode = EFFECT_BUFFER_ACCESS_READ;
    ctx->config.inputCfg.format = AUDIO_FORMAT_PCM_16_BIT;
    ctx->config.inputCfg.channels = AUDIO_CHANNEL_OUT_STEREO;
    ctx->config.inputCfg.samplingRate = audioshift::DEFAULT_SAMPLE_RATE;
    ctx->config.inputCfg.bufferProvider.getBuffer = nullptr;
    ctx->config.inputCfg.bufferProvider.releaseBuffer = nullptr;
    ctx->config.outputCfg.accessMode = EFFECT_BUFFER_ACCESS_ACCUMULATE;
    ctx->config.outputCfg.format = AUDIO_FORMAT_PCM_16_BIT;
    ctx->config.outputCfg.channels = AUDIO_CHANNEL_OUT_STEREO;
    ctx->config.outputCfg.samplingRate = audioshift::DEFAULT_SAMPLE_RATE;
    ctx->config.outputCfg.bufferProvider.getBuffer = nullptr;
    ctx->config.outputCfg.bufferProvider.releaseBuffer = nullptr;

    // Initialise SoundTouch
    SoundTouch *st = new (std::nothrow) SoundTouch();
    if (!st)
    {
        delete ctx;
        return -ENOMEM;
    }
    st->setChannels(audioshift::DEFAULT_CHANNELS);
    st->setSampleRate(audioshift::DEFAULT_SAMPLE_RATE);
    st->setPitchSemiTones(ctx->pitchSemitones);
    st->setSetting(SETTING_USE_QUICKSEEK, 1); // lower latency
    st->setSetting(SETTING_USE_AA_FILTER, 1); // anti-alias
    ctx->soundtouch = static_cast<void *>(st);

    *pHandle = reinterpret_cast<effect_handle_t>(ctx);
    ASHIFT_LOGI("EffectCreate: AudioShift instance created (pitch=%.4f st)",
                ctx->pitchSemitones);
    return 0;
}

extern "C" int EffectRelease(effect_handle_t handle)
{
    if (!handle)
        return -EINVAL;
    auto *ctx = reinterpret_cast<audioshift::AudioShiftContext *>(handle);
    ASHIFT_LOGI("EffectRelease: processed %" PRIu64 " frames", ctx->frameCount);
    if (ctx->soundtouch)
    {
        delete static_cast<SoundTouch *>(ctx->soundtouch);
    }
    delete ctx;
    return 0;
}

extern "C" int EffectGetDescriptor(const effect_uuid_t * /*uuid*/,
                                   effect_descriptor_t *pDescriptor)
{
    if (!pDescriptor)
        return -EINVAL;
    *pDescriptor = audioshift::AUDIOSHIFT_EFFECT_DESCRIPTOR;
    return 0;
}

extern "C" int EffectQueryNumberEffects(uint32_t *pNumEffects)
{
    if (!pNumEffects)
        return -EINVAL;
    *pNumEffects = 1;
    return 0;
}

extern "C" int EffectQueryEffect(uint32_t index, effect_descriptor_t *pDescriptor)
{
    if (!pDescriptor)
        return -EINVAL;
    if (index > 0)
        return -ENOENT;
    *pDescriptor = audioshift::AUDIOSHIFT_EFFECT_DESCRIPTOR;
    return 0;
}

// ─── Effect process (hot path) ────────────────────────────────────────────────

static int effectProcess(effect_handle_t self,
                         audio_buffer_t *inBuf,
                         audio_buffer_t *outBuf)
{
    auto *ctx = reinterpret_cast<audioshift::AudioShiftContext *>(self);
    if (!ctx || !inBuf || !outBuf)
        return -EINVAL;

    // Pass-through if disabled
    if (!ctx->enabled)
    {
        if (outBuf->raw != inBuf->raw)
        {
            memcpy(outBuf->raw, inBuf->raw,
                   inBuf->frameCount * 2 * sizeof(int16_t)); // stereo
        }
        return 0;
    }

    const int frames = static_cast<int>(inBuf->frameCount);
    const int channels = 2; // stereo

    if (frames <= 0 || frames > audioshift::MAX_FRAME_SIZE)
    {
        ASHIFT_LOGW("effectProcess: unexpected frameCount=%d", frames);
        return -EINVAL;
    }

    const double t0 = nowMs();

    SoundTouch *st = static_cast<SoundTouch *>(ctx->soundtouch);

    // 1. int16_t PCM → float32
    pcm16ToFloat(inBuf->s16, ctx->floatBuf, frames, channels);

    // 2. Feed to SoundTouch
    st->putSamples(ctx->floatBuf, static_cast<uint32_t>(frames));

    // 3. Drain processed samples
    uint32_t received = st->receiveSamples(ctx->floatBuf,
                                           static_cast<uint32_t>(frames));

    // If SoundTouch hasn't buffered enough yet, receive what we can and
    // zero-fill the rest to avoid glitches during the initial fill period.
    if (received < static_cast<uint32_t>(frames))
    {
        const int missing = frames - static_cast<int>(received);
        memset(ctx->floatBuf + received * channels, 0,
               missing * channels * sizeof(float));
    }

    // 4. float32 → int16_t PCM
    floatToPcm16(ctx->floatBuf, outBuf->s16, frames, channels);

    // 5. Update stats
    ctx->frameCount += static_cast<uint64_t>(frames);
    ctx->lastLatencyMs = static_cast<float>(nowMs() - t0);

    return 0;
}

// ─── Effect commands ──────────────────────────────────────────────────────────

static int effectCommand(effect_handle_t self,
                         uint32_t cmdCode,
                         uint32_t cmdSize,
                         void *pCmdData,
                         uint32_t *replySize,
                         void *pReplyData)
{
    auto *ctx = reinterpret_cast<audioshift::AudioShiftContext *>(self);
    if (!ctx)
        return -EINVAL;

    switch (cmdCode)
    {

    case EFFECT_CMD_INIT:
        ASHIFT_LOGD("CMD_INIT");
        if (!replySize || *replySize < sizeof(int) || !pReplyData)
            return -EINVAL;
        *(int *)pReplyData = 0;
        return 0;

    case EFFECT_CMD_SET_CONFIG:
    {
        if (cmdSize < sizeof(effect_config_t) || !pCmdData)
            return -EINVAL;
        if (!replySize || *replySize < sizeof(int) || !pReplyData)
            return -EINVAL;

        const auto *cfg = static_cast<const effect_config_t *>(pCmdData);
        ctx->config = *cfg;

        const int sr = static_cast<int>(cfg->inputCfg.samplingRate);
        const int ch = audio_channel_count_from_out_mask(cfg->inputCfg.channels);
        SoundTouch *st = static_cast<SoundTouch *>(ctx->soundtouch);
        st->setSampleRate(static_cast<uint32_t>(sr));
        st->setChannels(static_cast<uint32_t>(ch));
        st->setPitchSemiTones(ctx->pitchSemitones);
        st->clear();

        ASHIFT_LOGI("CMD_SET_CONFIG: sr=%d ch=%d", sr, ch);
        *(int *)pReplyData = 0;
        return 0;
    }

    case EFFECT_CMD_GET_CONFIG:
        if (!pReplyData || !replySize || *replySize < sizeof(effect_config_t))
            return -EINVAL;
        *(effect_config_t *)pReplyData = ctx->config;
        return 0;

    case EFFECT_CMD_RESET:
        static_cast<SoundTouch *>(ctx->soundtouch)->clear();
        ctx->frameCount = 0;
        ctx->lastLatencyMs = 0.0f;
        ctx->lastCpuPercent = 0.0f;
        return 0;

    case EFFECT_CMD_ENABLE:
        ctx->enabled = true;
        ASHIFT_LOGI("AudioShift ENABLED — 440→432 Hz active");
        if (replySize && *replySize >= sizeof(int) && pReplyData)
            *(int *)pReplyData = 0;
        return 0;

    case EFFECT_CMD_DISABLE:
        ctx->enabled = false;
        static_cast<SoundTouch *>(ctx->soundtouch)->clear();
        ASHIFT_LOGI("AudioShift DISABLED — pass-through mode");
        if (replySize && *replySize >= sizeof(int) && pReplyData)
            *(int *)pReplyData = 0;
        return 0;

    case EFFECT_CMD_GET_DESCRIPTOR:
        if (!pReplyData || !replySize || *replySize < sizeof(effect_descriptor_t))
            return -EINVAL;
        *(effect_descriptor_t *)pReplyData = audioshift::AUDIOSHIFT_EFFECT_DESCRIPTOR;
        return 0;

        // ── Proprietary commands ──────────────────────────────────────────────────

    case audioshift::CMD_SET_PITCH_RATIO:
    {
        if (cmdSize < sizeof(float) || !pCmdData)
            return -EINVAL;
        const float ratio = *(const float *)pCmdData;
        if (ratio <= 0.0f || ratio > 2.0f)
            return -EINVAL;
        // Convert ratio to semitones: 12 * log2(ratio)
        ctx->pitchSemitones = 12.0f * log2f(ratio);
        static_cast<SoundTouch *>(ctx->soundtouch)->setPitchSemiTones(ctx->pitchSemitones);
        ASHIFT_LOGI("CMD_SET_PITCH_RATIO: ratio=%.6f → %.4f semitones", ratio, ctx->pitchSemitones);
        if (replySize && *replySize >= sizeof(int) && pReplyData)
            *(int *)pReplyData = 0;
        return 0;
    }

    case audioshift::CMD_GET_LATENCY_MS:
        if (!pReplyData || !replySize || *replySize < sizeof(float))
            return -EINVAL;
        *(float *)pReplyData = ctx->lastLatencyMs;
        return 0;

    case audioshift::CMD_GET_CPU_USAGE:
        if (!pReplyData || !replySize || *replySize < sizeof(float))
            return -EINVAL;
        *(float *)pReplyData = ctx->lastCpuPercent;
        return 0;

    case audioshift::CMD_RESET_STATS:
        ctx->frameCount = 0;
        ctx->lastLatencyMs = 0.0f;
        ctx->lastCpuPercent = 0.0f;
        return 0;

    default:
        ASHIFT_LOGW("effectCommand: unknown cmd=0x%08x", cmdCode);
        return -EINVAL;
    }
}

static int effectGetDescriptor(effect_handle_t self,
                               effect_descriptor_t *pDescriptor)
{
    auto *ctx = reinterpret_cast<audioshift::AudioShiftContext *>(self);
    if (!ctx || !pDescriptor)
        return -EINVAL;
    *pDescriptor = audioshift::AUDIOSHIFT_EFFECT_DESCRIPTOR;
    return 0;
}

static int effectProcessReverse(effect_handle_t /*self*/,
                                audio_buffer_t * /*in*/,
                                audio_buffer_t * /*out*/)
{
    // AudioShift is an output effect; no reverse processing needed.
    return -ENOSYS;
}
