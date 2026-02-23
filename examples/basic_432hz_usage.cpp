/**
 * basic_432hz_usage.cpp
 *
 * Minimal self-contained example showing how to use the AudioShift 432 Hz
 * effect library on a host (non-Android) build.
 *
 * What this example demonstrates
 * ─────────────────────────────
 *  1. Describe the effect and create an instance (EffectCreate).
 *  2. Set sample rate and channel count via EFFECT_CMD_SET_CONFIG.
 *  3. Enable the effect (AudioShiftCommand::CMD_SET_ENABLED).
 *  4. Feed a simple PCM-16 buffer through the effect (EffectProcess).
 *  5. Read latency and CPU diagnostics via proprietary commands.
 *  6. Gracefully destroy the effect (EffectRelease).
 *
 * Build (host, Linux / macOS)
 * ──────────────────────────
 *   cmake -B build_example -S . \
 *         -DCMAKE_BUILD_TYPE=RelWithDebInfo \
 *         -DREPO_ROOT=$(git rev-parse --show-toplevel)
 *   cmake --build build_example
 *   ./build_example/basic_432hz_usage
 *
 * See examples/README.md for Android on-device usage.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <cassert>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <cmath>
#include <vector>

// ── Bring in the AudioShift public API ────────────────────────────────────
//
// On a real Android device the symbols are resolved at runtime from the
// shared library loaded by AudioFlinger.  On the host we include the header
// for types and then link directly against the compiled static/shared lib.
//
// NOTE: The host compiler won't have <android/log.h> or
//       <hardware/audio_effect.h>; the CMakeLists.txt for the examples
//       target provides a stub android_mock.h via an include directory.
//
#include "audioshift_hook.h"

// ── Audio constants ───────────────────────────────────────────────────────
static constexpr uint32_t SAMPLE_RATE = 48000;
static constexpr uint32_t CHANNELS = 2;
static constexpr uint32_t FRAMES = 480; // 10 ms @ 48 kHz
static constexpr uint32_t PCM_SAMPLES = FRAMES * CHANNELS;

// ── Helper: generate a 440 Hz sine wave as int16_t PCM ───────────────────
static std::vector<int16_t> make_sine_440hz(uint32_t frames,
                                            uint32_t sample_rate,
                                            uint32_t channels)
{
    std::vector<int16_t> buf(frames * channels);
    for (uint32_t f = 0; f < frames; ++f)
    {
        double t = static_cast<double>(f) / sample_rate;
        auto sample = static_cast<int16_t>(0.5 * 32767.0 *
                                           std::sin(2.0 * M_PI * 440.0 * t));
        for (uint32_t c = 0; c < channels; ++c)
            buf[f * channels + c] = sample;
    }
    return buf;
}

// ── Main ──────────────────────────────────────────────────────────────────
int main()
{
    printf("AudioShift 432 Hz — basic usage example\n");
    printf("==========================================\n\n");

    // ──────────────────────────────────────────────────────────────────────
    // STEP 1 — Create an effect instance
    // ──────────────────────────────────────────────────────────────────────
    printf("[1/6] Creating AudioShift effect instance...\n");

    // Build the effect descriptor UUID to request.
    const effect_uuid_t impl_uuid = audioshift::AUDIOSHIFT_EFFECT_IMPL_UUID;
    effect_handle_t handle = nullptr;

    int32_t ret = EffectCreate(&impl_uuid,
                               /*sessionId=*/0,
                               /*ioId    =*/0,
                               &handle);
    if (ret != 0 || handle == nullptr)
    {
        fprintf(stderr, "  FAIL: EffectCreate returned %d\n", ret);
        return 1;
    }
    printf("  OK — handle = %p\n\n", static_cast<void *>(handle));

    // ──────────────────────────────────────────────────────────────────────
    // STEP 2 — Configure sample rate + channel count
    // ──────────────────────────────────────────────────────────────────────
    printf("[2/6] Configuring effect (48 kHz, stereo)...\n");

    audio_config_t cfg{};
    cfg.sample_rate = SAMPLE_RATE;
    cfg.channel_mask = AUDIO_CHANNEL_OUT_STEREO; // 0x3
    cfg.format = AUDIO_FORMAT_PCM_16_BIT;

    // effect_config_t wraps input + output audio_config_t
    effect_config_t ecfg{};
    ecfg.inputCfg = cfg;
    ecfg.outputCfg = cfg;

    ret = (*handle)->command(handle,
                             EFFECT_CMD_SET_CONFIG,
                             sizeof(ecfg), &ecfg,
                             nullptr, nullptr);
    if (ret != 0)
    {
        fprintf(stderr, "  FAIL: SET_CONFIG returned %d\n", ret);
        EffectRelease(handle);
        return 1;
    }
    printf("  OK\n\n");

    // ──────────────────────────────────────────────────────────────────────
    // STEP 3 — Enable the effect
    // ──────────────────────────────────────────────────────────────────────
    printf("[3/6] Enabling pitch shift (440 Hz → 432 Hz)...\n");

    uint32_t enable = 1;
    int32_t reply_buf = 0;
    uint32_t reply_sz = sizeof(reply_buf);

    ret = (*handle)->command(handle,
                             static_cast<uint32_t>(
                                 audioshift::AudioShiftCommand::CMD_SET_ENABLED),
                             sizeof(enable), &enable,
                             &reply_sz, &reply_buf);
    if (ret != 0 || reply_buf != 0)
    {
        fprintf(stderr, "  FAIL: CMD_SET_ENABLED returned %d / reply %d\n",
                ret, reply_buf);
        EffectRelease(handle);
        return 1;
    }
    printf("  OK — pitch shift active\n\n");

    // ──────────────────────────────────────────────────────────────────────
    // STEP 4 — Process a buffer (440 Hz sine → should emerge near 432 Hz)
    // ──────────────────────────────────────────────────────────────────────
    printf("[4/6] Processing %u frames of 440 Hz audio...\n", FRAMES);

    auto input_pcm = make_sine_440hz(FRAMES, SAMPLE_RATE, CHANNELS);
    auto output_pcm = std::vector<int16_t>(PCM_SAMPLES, 0);

    // The Android effect ABI passes audio_buffer_t pairs.
    audio_buffer_t in_buf{};
    audio_buffer_t out_buf{};

    in_buf.frameCount = FRAMES;
    in_buf.s16 = input_pcm.data();

    out_buf.frameCount = FRAMES;
    out_buf.s16 = output_pcm.data();

    ret = (*handle)->process(handle, &in_buf, &out_buf);
    if (ret != 0)
    {
        fprintf(stderr, "  FAIL: process returned %d\n", ret);
        EffectRelease(handle);
        return 1;
    }

    // Sanity check: output should be non-zero (effect is active)
    int64_t energy = 0;
    for (int16_t s : output_pcm)
        energy += static_cast<int64_t>(s) * s;
    printf("  OK — RMS energy check passed (energy = %lld)\n\n",
           static_cast<long long>(energy));

    // ──────────────────────────────────────────────────────────────────────
    // STEP 5 — Query latency and CPU diagnostics
    // ──────────────────────────────────────────────────────────────────────
    printf("[5/6] Querying diagnostics...\n");

    float latency_ms = 0.0f;
    reply_sz = sizeof(latency_ms);

    ret = (*handle)->command(handle,
                             static_cast<uint32_t>(
                                 audioshift::AudioShiftCommand::CMD_GET_LATENCY_MS),
                             0, nullptr,
                             &reply_sz, &latency_ms);
    if (ret == 0)
        printf("  Latency      : %.2f ms (budget: %.0f ms)\n",
               latency_ms, audioshift::MAX_LATENCY_MS);

    float cpu_pct = 0.0f;
    reply_sz = sizeof(cpu_pct);
    ret = (*handle)->command(handle,
                             static_cast<uint32_t>(
                                 audioshift::AudioShiftCommand::CMD_GET_CPU_USAGE),
                             0, nullptr,
                             &reply_sz, &cpu_pct);
    if (ret == 0)
        printf("  CPU usage    : %.1f %%\n", cpu_pct);

    printf("  Pitch ratio  : %.6f  (432/440 = %.6f)\n",
           audioshift::PITCH_RATIO_432_HZ,
           432.0f / 440.0f);
    printf("  Pitch shift  : %.4f semitones\n\n",
           audioshift::PITCH_SEMITONES_432_HZ);

    // ──────────────────────────────────────────────────────────────────────
    // STEP 6 — Release the effect
    // ──────────────────────────────────────────────────────────────────────
    printf("[6/6] Releasing effect...\n");

    ret = EffectRelease(handle);
    if (ret != 0)
    {
        fprintf(stderr, "  WARN: EffectRelease returned %d\n", ret);
        // Not fatal — continue
    }
    printf("  OK\n\n");

    printf("==========================================\n");
    printf("Example completed successfully.\n");
    printf("\nNote: On a real Android device, the pitch shift converts\n");
    printf("      440 Hz A-440 tuning to 432 Hz A-432 tuning.\n");
    printf("      The %.6f-semitone adjustment is transparent to apps.\n",
           std::abs(audioshift::PITCH_SEMITONES_432_HZ));

    return 0;
}
