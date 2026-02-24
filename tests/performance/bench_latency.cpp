// tests/performance/bench_latency.cpp
// Host-side latency regression: mock effectProcess() must complete < 10 ms mean.
#include <gtest/gtest.h>
#include <time.h>

#include <cmath>
#include <cstdint>
#include <vector>

static double clock_ms()
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1e3 + ts.tv_nsec * 1e-6;
}

// Minimal mock of effectProcess(): buffer copy + lightweight DSP stand-in.
// Simulates SoundTouch pitch ratio multiply — O(n) work, no alloc.
static void mock_effect_process(float* buf, int frames)
{
    const float ratio = 432.0f / 440.0f;
    for (int i = 0; i < frames * 2; ++i) buf[i] *= ratio;
}

TEST(LatencyBench, EffectProcessUnder10ms)
{
    constexpr int FRAMES = 8192;  // MAX_FRAME_SIZE
    constexpr int WARMUP = 3;
    constexpr int SAMPLES = 20;
    constexpr double LIMIT_MS = 10.0;

    std::vector<float> buf(FRAMES * 2, 0.5f);

    // Warmup — ensure instruction caches are hot
    for (int i = 0; i < WARMUP; ++i) mock_effect_process(buf.data(), FRAMES);

    // Benchmark
    std::vector<double> times(SAMPLES);
    for (int i = 0; i < SAMPLES; ++i)
    {
        double t0 = clock_ms();
        mock_effect_process(buf.data(), FRAMES);
        times[i] = clock_ms() - t0;
    }

    double sum = 0;
    for (double t : times) sum += t;
    double mean_ms = sum / SAMPLES;

    // Print for CI log
    printf("[bench_latency] mean=%.4f ms  limit=%.1f ms  samples=%d\n", mean_ms, LIMIT_MS, SAMPLES);

    EXPECT_LT(mean_ms, LIMIT_MS) << "Mean effectProcess() latency " << mean_ms
                                 << " ms exceeds < 10 ms target";
}

int main(int argc, char** argv)
{
    ::testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}
