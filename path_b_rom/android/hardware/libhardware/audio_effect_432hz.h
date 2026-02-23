#pragma once

#include <hardware/audio_effect.h>

// AudioShift 432Hz Effect — HAL-level type definitions

#define AUDIOSHIFT_432HZ_EFFECT_NAME "AudioShift432Hz"

#define AUDIOSHIFT_432HZ_IMPL_UUID \
    { 0xf22a9ce0, 0x7a11, 0x11ee, 0xb962, \
      { 0x02, 0x42, 0xac, 0x12, 0x00, 0x02 } }

#define AUDIOSHIFT_432HZ_TYPE_UUID \
    { 0x7b491460, 0x8d4d, 0x11e0, 0xbd61, \
      { 0x00, 0x02, 0xa5, 0xd5, 0xc5, 0x1b } }

// Parameter IDs for EFFECT_CMD_SET_PARAM / EFFECT_CMD_GET_PARAM
typedef enum {
    AUDIOSHIFT_PARAM_ENABLED       = 0,  // int32: 0=off, 1=on
    AUDIOSHIFT_PARAM_PITCH_CENTS   = 1,  // int32: pitch in centitones (-3177 for 432Hz)
    AUDIOSHIFT_PARAM_LATENCY_MS    = 2,  // int32: read-only latency estimate
} AudioShift432HzParam;
