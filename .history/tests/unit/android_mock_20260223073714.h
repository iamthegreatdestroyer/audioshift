/**
 * android_mock.h — Minimal stubs for Android Audio Effect API types
 *
 * Allows audioshift_hook.h to be included on a non-Android host for
 * unit testing. Only the types exercised by unit tests are stubbed.
 *
 * DO NOT use in production Android builds — use the real NDK headers.
 */

#pragma once

#include <cstdint>
#include <cstring>

// ── android/log.h stub ─────────────────────────────────────────────────────

#define ANDROID_LOG_INFO    4
#define ANDROID_LOG_WARN    5
#define ANDROID_LOG_ERROR   6
#define ANDROID_LOG_DEBUG   3

static inline int __android_log_print(int /*prio*/, const char * /*tag*/,
                                       const char * /*fmt*/, ...) { return 0; }

// ── hardware/audio_effect.h stubs ──────────────────────────────────────────

/** UUID type (ABI-compatible with Android's effect_uuid_t) */
typedef struct {
    uint32_t timeLow;
    uint16_t timeMid;
    uint16_t timeHiAndVersion;
    uint16_t clockSeq;
    uint8_t  node[6];
} effect_uuid_t;

/** Opaque effect handle */
typedef void* effect_handle_t;

/** Forward declaration (we never need its internals in these tests) */
struct effect_interface_s;

/** Audio configuration block */
typedef struct {
    uint32_t sample_rate;
    uint32_t channel_mask;
    uint8_t  format;
} audio_config_t;

/** Effect descriptor */
typedef struct {
    effect_uuid_t type;
    effect_uuid_t uuid;
    uint32_t      apiVersion;
    uint32_t      flags;
    uint16_t      cpuLoad;
    uint16_t      memoryUsage;
    char          name[64];
    char          implementor[64];
} effect_descriptor_t;

/** Android audio effect API version (from NDK headers) */
#define EFFECT_CONTROL_API_VERSION 0x0003

/** Effect flags */
#define EFFECT_FLAG_TYPE_INSERT        0x00000001
#define EFFECT_FLAG_INSERT_LAST        0x00000040
#define EFFECT_FLAG_DEVICE_IND         0x00000800
#define EFFECT_FLAG_AUDIO_MODE_IND     0x00001000

/** First proprietary command code */
#define EFFECT_CMD_FIRST_PROPRIETARY   0x10000
