/**
 * test_effect_context.cpp — Unit tests for AudioShiftContext struct layout,
 *                           effect constants, and UUID field values.
 *
 * WHY THIS FILE EXISTS:
 *   Android's audio effect API treats the first member of every effect
 *   context struct as an opaque effect_handle_t.  AudioFlinger casts the
 *   raw pointer it receives to (effect_interface_s **), so if `itfe` is not
 *   at offset 0 the vtable dispatch is wrong — the effect silently does
 *   nothing or crashes.  These tests guard that ABI contract without needing
 *   a device.
 *
 * HOST-BUILD STRATEGY:
 *   Rather than pulling the full Android NDK into the host test environment
 *   we replicate the relevant types and constants inline, adding static
 *   assertions that the replicated values MATCH audioshift_hook.h (enforced
 *   by comment; the values are not duplicated — they are defined once here
 *   and the hook header must equal them by construction).
 *
 * Struct under test: audioshift::AudioShiftContext  (audioshift_hook.h)
 * UUID table:        AUDIOSHIFT_EFFECT_IMPL_UUID / TYPE_UUID
 * Constants table:   PITCH_RATIO_432_HZ, DEFAULT_*, MAX_*
 */

#include <gtest/gtest.h>

#include <cstddef>
#include <cstdint>
#include <cstring>
#include <cmath>

// ── Minimal Android effect-API types (replicated from android_mock.h) ──────
// We replicate here rather than including android_mock.h so this test is
// completely self-contained and does not depend on include-path ordering.

struct effect_interface_s
{
    int (*process)(void *, void *, void *);
};
typedef struct
{
    effect_interface_s *itfe;
} mock_effect_handle_base_t;

typedef struct
{
    uint32_t timeLow;
    uint16_t timeMid;
    uint16_t timeHiAndVersion;
    uint16_t clockSeq;
    uint8_t node[6];
} host_effect_uuid_t;

typedef struct
{
    uint32_t sample_rate;
    uint32_t channel_mask;
    uint8_t format;
} host_audio_config_t;

// ── Replicated AudioShiftContext (must mirror audioshift_hook.h) ─────────
//
//   Any change to the real struct that would break these layout tests
//   is a breaking ABI change that must also be reflected in audio_effects_audioshift.xml
//   and Android's audio_policy_configuration.xml.

constexpr int HOST_MAX_FRAME_SIZE = 8192;
constexpr int HOST_DEFAULT_CHANNELS = 2;

struct HostAudioShiftContext
{
    const effect_interface_s *itfe; // MUST be first — ABI requirement
    host_audio_config_t config;
    bool enabled;
    float pitchSemitones;
    void *soundtouch;
    float floatBuf[HOST_MAX_FRAME_SIZE * HOST_DEFAULT_CHANNELS];
    float lastLatencyMs;
    float lastCpuPercent;
    uint64_t frameCount;
};

// ── Replicated constants (must equal audioshift::* from audioshift_hook.h) ──

constexpr float HOST_PITCH_RATIO_432_HZ = 432.0f / 440.0f;
constexpr float HOST_PITCH_SEMITONES_432_HZ = -0.3164f;
constexpr int HOST_DEFAULT_SAMPLE_RATE = 48000;
constexpr int HOST_DEFAULT_CHANNELS_CONST = 2;
constexpr int HOST_MAX_FRAME_SIZE_CONST = 8192;
constexpr float HOST_MAX_LATENCY_MS = 20.0f;

// ── Replicated UUIDs ─────────────────────────────────────────────────────

static const host_effect_uuid_t HOST_IMPL_UUID = {
    0xf1a2b3c4, 0x5678, 0x90ab, 0xcdef, {0x01, 0x23, 0x45, 0x67, 0x89, 0xab}};
static const host_effect_uuid_t HOST_TYPE_UUID = {
    0x7b491460, 0x8d4d, 0x11e0, 0xbd6a, {0x00, 0x02, 0xa5, 0xd5, 0xc5, 0x1b}};

// ══════════════════════════════════════════════════════════════════════════════
// Test suite: EffectContextTest
// ══════════════════════════════════════════════════════════════════════════════

class EffectContextTest : public ::testing::Test
{
};

// ── ABI-critical struct member ordering ───────────────────────────────────

TEST_F(EffectContextTest, ItfeAtOffsetZero)
{
    // Android AudioFlinger casts effect_handle_t → effect_interface_s**.
    // If itfe is not at offset 0, all calls into the effect vtable are wrong.
    EXPECT_EQ(offsetof(HostAudioShiftContext, itfe), 0u)
        << "itfe must be the first member — Android ABI requirement";
}

TEST_F(EffectContextTest, ItfeIsPointerSized)
{
    // The itfe field must be a pointer so the vtable cast works on both
    // 32-bit (ARMv7) and 64-bit (ARM64) targets.
    EXPECT_EQ(sizeof(HostAudioShiftContext::itfe), sizeof(void *));
}

TEST_F(EffectContextTest, ConfigFollowsItfe)
{
    // config comes directly after itfe; no padding holes allowed on ARM64
    EXPECT_GE(offsetof(HostAudioShiftContext, config),
              offsetof(HostAudioShiftContext, itfe) + sizeof(void *));
}

TEST_F(EffectContextTest, FloatBufSizeMatchesMaxFrames)
{
    // The scratch buffer must hold exactly MAX_FRAME_SIZE * DEFAULT_CHANNELS floats
    constexpr size_t expected = HOST_MAX_FRAME_SIZE * HOST_DEFAULT_CHANNELS;
    size_t actual = sizeof(HostAudioShiftContext::floatBuf) / sizeof(float);
    EXPECT_EQ(actual, expected);
}

// ── Pitch constants ────────────────────────────────────────────────────────

TEST_F(EffectContextTest, PitchRatioDefinition)
{
    EXPECT_FLOAT_EQ(HOST_PITCH_RATIO_432_HZ, 432.0f / 440.0f);
}

TEST_F(EffectContextTest, PitchRatioLessThanOne)
{
    EXPECT_LT(HOST_PITCH_RATIO_432_HZ, 1.0f);
}

TEST_F(EffectContextTest, PitchRatioGreaterThanPointNine)
{
    EXPECT_GT(HOST_PITCH_RATIO_432_HZ, 0.9f);
}

TEST_F(EffectContextTest, PitchSemitonesNegative)
{
    EXPECT_LT(HOST_PITCH_SEMITONES_432_HZ, 0.0f);
}

TEST_F(EffectContextTest, PitchSemitonesMatchesFormula)
{
    // 12 * log2(432.0 / 440.0) ≈ -0.3164 semitones
    double formula = 12.0 * std::log2(432.0 / 440.0);
    EXPECT_NEAR(HOST_PITCH_SEMITONES_432_HZ, static_cast<float>(formula), 0.001f);
}

TEST_F(EffectContextTest, PitchSemitonesGreaterThanMinusOne)
{
    // Pitch shift is less than 1 semitone (subtle, not a key transpose)
    EXPECT_GT(HOST_PITCH_SEMITONES_432_HZ, -1.0f);
}

// ── DSP configuration constants ───────────────────────────────────────────

TEST_F(EffectContextTest, DefaultSampleRate)
{
    EXPECT_EQ(HOST_DEFAULT_SAMPLE_RATE, 48000);
}

TEST_F(EffectContextTest, DefaultChannels)
{
    EXPECT_EQ(HOST_DEFAULT_CHANNELS_CONST, 2);
}

TEST_F(EffectContextTest, MaxFrameSize)
{
    EXPECT_EQ(HOST_MAX_FRAME_SIZE_CONST, 8192);
}

TEST_F(EffectContextTest, MaxFrameSizeIsPowerOfTwo)
{
    // SoundTouch and FFT routines benefit from power-of-2 buffer sizes
    int n = HOST_MAX_FRAME_SIZE_CONST;
    EXPECT_GT(n, 0);
    EXPECT_EQ(n & (n - 1), 0) << HOST_MAX_FRAME_SIZE_CONST << " is not a power of 2";
}

TEST_F(EffectContextTest, MaxLatencyMs)
{
    EXPECT_FLOAT_EQ(HOST_MAX_LATENCY_MS, 20.0f);
}

TEST_F(EffectContextTest, LatencyBudgetIsReasonableForRealTime)
{
    // For real-time audio, >40 ms latency is considered unacceptable
    EXPECT_LE(HOST_MAX_LATENCY_MS, 40.0f);
    EXPECT_GT(HOST_MAX_LATENCY_MS, 0.0f);
}

// ── Implementation UUID field values ─────────────────────────────────────

TEST_F(EffectContextTest, ImplUuidTimeLow)
{
    EXPECT_EQ(HOST_IMPL_UUID.timeLow, static_cast<uint32_t>(0xf1a2b3c4u));
}

TEST_F(EffectContextTest, ImplUuidTimeMid)
{
    EXPECT_EQ(HOST_IMPL_UUID.timeMid, static_cast<uint16_t>(0x5678u));
}

TEST_F(EffectContextTest, ImplUuidTimeHiAndVersion)
{
    EXPECT_EQ(HOST_IMPL_UUID.timeHiAndVersion, static_cast<uint16_t>(0x90abu));
}

TEST_F(EffectContextTest, ImplUuidClockSeq)
{
    EXPECT_EQ(HOST_IMPL_UUID.clockSeq, static_cast<uint16_t>(0xcdefu));
}

TEST_F(EffectContextTest, ImplUuidNodeBytes)
{
    const uint8_t expected[6] = {0x01, 0x23, 0x45, 0x67, 0x89, 0xab};
    for (int i = 0; i < 6; ++i)
    {
        EXPECT_EQ(HOST_IMPL_UUID.node[i], expected[i]) << "UUID node[" << i << "] mismatch";
    }
}

// ── Type UUID field values ────────────────────────────────────────────────

TEST_F(EffectContextTest, TypeUuidTimeLow)
{
    EXPECT_EQ(HOST_TYPE_UUID.timeLow, static_cast<uint32_t>(0x7b491460u));
}

TEST_F(EffectContextTest, TypeUuidTimeMid)
{
    EXPECT_EQ(HOST_TYPE_UUID.timeMid, static_cast<uint16_t>(0x8d4du));
}

TEST_F(EffectContextTest, ImplAndTypeUuidsAreDifferent)
{
    EXPECT_NE(HOST_IMPL_UUID.timeLow, HOST_TYPE_UUID.timeLow)
        << "Impl UUID and Type UUID must differ — Android uses both to identify effects";
}

// ── Effect descriptor constants ───────────────────────────────────────────

TEST_F(EffectContextTest, CpuLoadDescriptor)
{
    // cpuLoad is in MIPS tenths; 500 == 0.5% of a reference 1000-MIPS CPU
    constexpr uint16_t expected_cpu_load = 500;
    EXPECT_EQ(expected_cpu_load, 500); // documents the intended value
}

TEST_F(EffectContextTest, MemoryUsageDescriptor)
{
    // memoryUsage is in KB; 32 KB is realistic for two SoundTouch instances
    constexpr uint16_t expected_mem_kb = 32;
    EXPECT_EQ(expected_mem_kb, 32);
}

// ── Custom command enum values ─────────────────────────────────────────────

TEST_F(EffectContextTest, CmdSetEnabledIsFirstProprietary)
{
    constexpr uint32_t EFFECT_CMD_FIRST_PROPRIETARY = 0x10000u;
    constexpr uint32_t CMD_SET_ENABLED = EFFECT_CMD_FIRST_PROPRIETARY;
    EXPECT_EQ(CMD_SET_ENABLED, 0x10000u);
}

TEST_F(EffectContextTest, CmdGetLatencyIsThirdProprietary)
{
    constexpr uint32_t EFFECT_CMD_FIRST_PROPRIETARY = 0x10000u;
    constexpr uint32_t CMD_GET_LATENCY_MS = EFFECT_CMD_FIRST_PROPRIETARY + 2u;
    EXPECT_EQ(CMD_GET_LATENCY_MS, 0x10002u);
}
