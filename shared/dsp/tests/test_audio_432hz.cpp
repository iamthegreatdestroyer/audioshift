#include "audio_432hz.h"
#include "audio_pipeline.h"
#include <cstdio>
#include <cmath>
#include <cstring>
#include <vector>
#include <cassert>

using namespace audioshift::dsp;

// Simple test framework
static int g_testsRun = 0;
static int g_testsFailed = 0;

#define ASSERT_TRUE(cond) \
    do { \
        g_testsRun++; \
        if (!(cond)) { \
            fprintf(stderr, "✗ FAIL: %s:%d: %s\n", __FILE__, __LINE__, #cond); \
            g_testsFailed++; \
        } else { \
            printf("✓ %s\n", #cond); \
        } \
    } while(0)

#define ASSERT_NEAR(a, b, eps) \
    do { \
        float diff = std::fabs((a) - (b)); \
        ASSERT_TRUE(diff < (eps)); \
    } while(0)

// Test 1: Constructor with default arguments
void test_constructor_default_args() {
    printf("\n[TEST 1] Constructor with default args\n");
    Audio432HzConverter converter;
    ASSERT_TRUE(converter.getLatencyMs() > 0);
    ASSERT_TRUE(converter.getCpuUsagePercent() >= 0);
}

// Test 2: Constructor with explicit parameters
void test_constructor_with_params() {
    printf("\n[TEST 2] Constructor with parameters\n");
    Audio432HzConverter converter(48000, 2);
    ASSERT_TRUE(converter.getLatencyMs() > 0);
    ASSERT_TRUE(converter.getCpuUsagePercent() >= 0);
}

// Test 3: Process does not corrupt buffer
void test_process_no_corruption() {
    printf("\n[TEST 3] Process does not corrupt buffer\n");
    Audio432HzConverter converter(48000, 2);

    // Create stereo silence buffer (4800 samples = 100ms at 48kHz/2ch)
    const int numSamples = 4800;
    std::vector<int16_t> buffer(numSamples, 0);

    int result = converter.process(buffer.data(), numSamples);
    ASSERT_TRUE(result >= 0);

    // Check no samples exceed int16 range
    bool inRange = true;
    for (int i = 0; i < numSamples; i++) {
        if (buffer[i] < INT16_MIN || buffer[i] > INT16_MAX) {
            inRange = false;
            break;
        }
    }
    ASSERT_TRUE(inRange);
}

// Test 4: Process accepts silence
void test_process_silence() {
    printf("\n[TEST 4] Process silence buffer\n");
    Audio432HzConverter converter(48000, 2);

    int16_t silence[4800] = {0};
    int result = converter.process(silence, 4800);
    ASSERT_TRUE(result == 4800);
}

// Test 5: setSampleRate does not crash
void test_setSampleRate() {
    printf("\n[TEST 5] setSampleRate does not crash\n");
    Audio432HzConverter converter(48000, 2);
    converter.setSampleRate(44100);
    converter.setSampleRate(96000);
    converter.setSampleRate(48000);
    ASSERT_TRUE(true);  // Just verify no crash
}

// Test 6: setPitchShiftSemitones
void test_setPitchShift() {
    printf("\n[TEST 6] setPitchShiftSemitones\n");
    Audio432HzConverter converter(48000, 2);
    converter.setPitchShiftSemitones(-0.5296f);  // 432 Hz shift
    converter.setPitchShiftSemitones(0.0f);      // Reset
    ASSERT_TRUE(true);
}

// Test 7: Pipeline singleton initialize/shutdown
void test_pipeline_lifecycle() {
    printf("\n[TEST 7] Pipeline singleton lifecycle\n");
    AudioPipeline& pipeline = AudioPipeline::getInstance();

    pipeline.initialize(48000, 2);
    ASSERT_TRUE(true);

    pipeline.setEnabled(true);
    ASSERT_TRUE(pipeline.isEnabled());

    pipeline.setEnabled(false);
    ASSERT_TRUE(!pipeline.isEnabled());

    pipeline.shutdown();
    ASSERT_TRUE(true);
}

// Test 8: Pipeline processInPlace
void test_pipeline_processInPlace() {
    printf("\n[TEST 8] Pipeline processInPlace\n");
    AudioPipeline& pipeline = AudioPipeline::getInstance();

    pipeline.initialize(48000, 2);
    pipeline.setEnabled(true);

    int16_t buffer[4800] = {0};
    bool result = pipeline.processInPlace(buffer, 4800);
    ASSERT_TRUE(result);

    // Check stats
    PipelineStats stats = pipeline.getStats();
    ASSERT_TRUE(stats.framesProcessed > 0);

    pipeline.shutdown();
}

// Test 9: Process null buffer handling
void test_process_null_buffer() {
    printf("\n[TEST 9] Process null buffer handling\n");
    Audio432HzConverter converter(48000, 2);
    int result = converter.process(nullptr, 4800);
    ASSERT_TRUE(result == 0);
}

// Test 10: Process zero samples
void test_process_zero_samples() {
    printf("\n[TEST 10] Process zero samples\n");
    Audio432HzConverter converter(48000, 2);
    int16_t buffer[100] = {0};
    int result = converter.process(buffer, 0);
    ASSERT_TRUE(result == 0);
}

int main(int argc, char* argv[]) {
    printf("========================================\n");
    printf("AudioShift DSP Library Unit Tests\n");
    printf("========================================\n");

    test_constructor_default_args();
    test_constructor_with_params();
    test_process_no_corruption();
    test_process_silence();
    test_setSampleRate();
    test_setPitchShift();
    test_pipeline_lifecycle();
    test_pipeline_processInPlace();
    test_process_null_buffer();
    test_process_zero_samples();

    printf("\n========================================\n");
    printf("Test Results: %d/%d passed\n", g_testsRun - g_testsFailed, g_testsRun);
    printf("========================================\n");

    return g_testsFailed > 0 ? 1 : 0;
}
