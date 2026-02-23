#include "AudioShift432Effect.h"
#include <audio_432hz.h>
#include <audio_pipeline.h>
#include <utils/Log.h>
#include <cstring>
#include <cerrno>

#define LOG_TAG "AudioShift432"

namespace android {

using audioshift::dsp::Audio432HzConverter;
using audioshift::dsp::AudioPipeline;

// Effect context structure
struct AudioShift432EffectContext {
    effect_interface_t itfe;
    Audio432HzConverter* converter;
    bool enabled;
    effect_config_t config;
};

// Effect processing interface
static int effect_process(effect_handle_t self,
                          audio_buffer_t* inBuffer,
                          audio_buffer_t* outBuffer) {
    auto* ctx = reinterpret_cast<AudioShift432EffectContext*>(self);
    if (!ctx || !ctx->enabled || !ctx->converter) {
        return -EINVAL;
    }

    // In-place processing
    int16_t* buffer = reinterpret_cast<int16_t*>(inBuffer->raw);
    uint32_t frameCount = inBuffer->frameCount;
    uint32_t channels = ctx->config.inputCfg.channels == AUDIO_CHANNEL_OUT_STEREO ? 2 : 1;

    if (outBuffer) {
        memcpy(outBuffer->raw, inBuffer->raw, frameCount * channels * sizeof(int16_t));
        buffer = reinterpret_cast<int16_t*>(outBuffer->raw);
    }

    ctx->converter->process(buffer, frameCount * channels);
    return 0;
}

// Effect command handler
static int effect_command(effect_handle_t self,
                          uint32_t cmdCode,
                          uint32_t cmdSize,
                          void* pCmdData,
                          uint32_t* replySize,
                          void* pReplyData) {
    auto* ctx = reinterpret_cast<AudioShift432EffectContext*>(self);
    if (!ctx) {
        return -EINVAL;
    }

    switch (cmdCode) {
        case EFFECT_CMD_INIT:
            ALOGI("EFFECT_CMD_INIT");
            if (!ctx->converter) {
                int sr = ctx->config.inputCfg.samplingRate > 0 ?
                         ctx->config.inputCfg.samplingRate : 48000;
                int ch = 2;
                ctx->converter = new Audio432HzConverter(sr, ch);
            }
            break;

        case EFFECT_CMD_ENABLE:
            ALOGI("EFFECT_CMD_ENABLE");
            ctx->enabled = true;
            break;

        case EFFECT_CMD_DISABLE:
            ALOGI("EFFECT_CMD_DISABLE");
            ctx->enabled = false;
            break;

        case EFFECT_CMD_SET_CONFIG:
            ALOGI("EFFECT_CMD_SET_CONFIG");
            if (pCmdData && cmdSize == sizeof(effect_config_t)) {
                memcpy(&ctx->config, pCmdData, sizeof(effect_config_t));
                if (ctx->converter) {
                    ctx->converter->setSampleRate(ctx->config.inputCfg.samplingRate);
                }
            }
            break;

        case EFFECT_CMD_RESET:
            ALOGI("EFFECT_CMD_RESET");
            if (ctx->converter) {
                int sr = ctx->config.inputCfg.samplingRate > 0 ?
                         ctx->config.inputCfg.samplingRate : 48000;
                ctx->converter->setSampleRate(sr);
            }
            break;

        case EFFECT_CMD_GET_PARAM:
            ALOGI("EFFECT_CMD_GET_PARAM");
            if (pReplyData && replySize) {
                *replySize = 0;
            }
            break;

        default:
            ALOGW("Unknown command: %u", cmdCode);
            break;
    }

    return 0;
}

// Get effect descriptor
static int effect_get_descriptor(effect_handle_t self,
                                  effect_descriptor_t* pDesc) {
    if (!pDesc) {
        return -EINVAL;
    }

    static const effect_uuid_t kTypeUUID = {
        0x7b491460, 0x8d4d, 0x11e0, 0xbd61,
        { 0x00, 0x02, 0xa5, 0xd5, 0xc5, 0x1b }
    };

    static const effect_uuid_t kImplUUID = {
        0xf22a9ce0, 0x7a11, 0x11ee, 0xb962,
        { 0x02, 0x42, 0xac, 0x12, 0x00, 0x02 }
    };

    memcpy(&pDesc->type, &kTypeUUID, sizeof(effect_uuid_t));
    memcpy(&pDesc->uuid, &kImplUUID, sizeof(effect_uuid_t));
    pDesc->apiVersion = EFFECT_CONTROL_API_VERSION;
    pDesc->flags = EFFECT_FLAG_TYPE_INSERT | EFFECT_FLAG_INSERT_LAST;
    pDesc->cpuLoad = 500;   // 5% CPU estimate
    pDesc->memoryUsage = 64; // 64KB
    strncpy(pDesc->name, "AudioShift 432Hz", EFFECT_STRING_LEN_MAX);
    strncpy(pDesc->implementor, "AudioShift Project", EFFECT_STRING_LEN_MAX);

    return 0;
}

// Effect interface function table
static const struct effect_interface_s kEffectInterface = {
    sizeof(struct effect_interface_s),
    effect_process,
    effect_command,
    effect_get_descriptor,
    nullptr  // process_reverse
};

// Create effect instance
static int effect_create(const effect_uuid_t* uuid,
                         int32_t sessionId,
                         int32_t ioId,
                         effect_handle_t* pHandle) {
    ALOGI("effect_create: sessionId=%d, ioId=%d", sessionId, ioId);

    auto* ctx = new AudioShift432EffectContext();
    if (!ctx) {
        return -ENOMEM;
    }

    ctx->itfe = kEffectInterface;
    ctx->converter = nullptr;
    ctx->enabled = false;
    memset(&ctx->config, 0, sizeof(ctx->config));
    ctx->config.inputCfg.samplingRate = 48000;
    ctx->config.inputCfg.channels = AUDIO_CHANNEL_OUT_STEREO;
    ctx->config.inputCfg.format = AUDIO_FORMAT_PCM_16_BIT;
    memcpy(&ctx->config.outputCfg, &ctx->config.inputCfg, sizeof(ctx->config.inputCfg));

    *pHandle = (effect_handle_t)ctx;
    return 0;
}

// Release effect instance
static int effect_release(effect_handle_t handle) {
    ALOGI("effect_release");
    auto* ctx = reinterpret_cast<AudioShift432EffectContext*>(handle);
    if (ctx) {
        if (ctx->converter) {
            delete ctx->converter;
        }
        delete ctx;
    }
    return 0;
}

// Get number of effects
static uint32_t effect_get_descriptor(const effect_uuid_t* uuid,
                                       effect_descriptor_t* pDescriptor) {
    if (!pDescriptor) {
        return 0;
    }

    static const effect_descriptor_t kDescriptor = {
        .type = { 0x7b491460, 0x8d4d, 0x11e0, 0xbd61,
                  { 0x00, 0x02, 0xa5, 0xd5, 0xc5, 0x1b } },
        .uuid = { 0xf22a9ce0, 0x7a11, 0x11ee, 0xb962,
                  { 0x02, 0x42, 0xac, 0x12, 0x00, 0x02 } },
        .apiVersion = EFFECT_CONTROL_API_VERSION,
        .flags = EFFECT_FLAG_TYPE_INSERT | EFFECT_FLAG_INSERT_LAST,
        .cpuLoad = 500,
        .memoryUsage = 64,
        .name = "AudioShift 432Hz",
        .implementor = "AudioShift Project"
    };

    *pDescriptor = kDescriptor;
    return 1;
}

// Audio effect library interface
audio_effect_library_t AUDIO_EFFECT_LIBRARY_INFO_SYM = {
    .tag = AUDIO_EFFECT_LIBRARY_TAG,
    .version = EFFECT_LIBRARY_API_VERSION,
    .name = "AudioShift 432Hz Effect Library",
    .implementor = "AudioShift Project",
    .create_effect = effect_create,
    .release_effect = effect_release,
    .get_descriptor = effect_get_descriptor,
};

}  // namespace android
