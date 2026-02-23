##############################################################################
# AudioShift — Unit Tests
#
# Host-side unit tests for:
#   1. Pitch ratio / semitone constants (no Android deps)
#   2. PCM16 ↔ float conversion math
#   3. Effect context struct layout (via minimal Android mock)
#
# Python-based "test_fft_analysis.py" is run separately via pytest.
#
# Build (host, any platform with CMake 3.15+):
#   cd tests/unit
#   cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
#   cmake --build build
#   ctest --test-dir build --output-on-failure
##############################################################################

cmake_minimum_required(VERSION 3.15)
project(audioshift_unit_tests CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ── GoogleTest ─────────────────────────────────────────────────────────────

include(FetchContent)

FetchContent_Declare(
    googletest
    URL https://github.com/google/googletest/archive/refs/tags/v1.14.0.zip
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
)

# For Windows: prevent overriding parent project compiler/linker settings
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(googletest)

# ── Include paths ──────────────────────────────────────────────────────────

# Repo root (for including shared/dsp/include, etc.)
set(REPO_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../..")

include_directories(
    "${CMAKE_CURRENT_SOURCE_DIR}"              # android_mock.h lives here
    "${REPO_ROOT}/path_c_magisk/native"        # audioshift_hook.h
    "${REPO_ROOT}/shared/dsp/include"          # audio_432hz.h, audio_pipeline.h
)

# ── Test targets ───────────────────────────────────────────────────────────

enable_testing()

# 1. Pitch ratio / semitone constants
add_executable(test_pitch_ratio test_pitch_ratio.cpp)
target_link_libraries(test_pitch_ratio GTest::gtest_main)
gtest_discover_tests(test_pitch_ratio)

# 2. PCM16 ↔ float conversion
add_executable(test_pcm_conversion test_pcm_conversion.cpp)
target_link_libraries(test_pcm_conversion GTest::gtest_main)
gtest_discover_tests(test_pcm_conversion)

# 3. Effect context layout (uses android_mock.h to stub Android headers)
add_executable(test_effect_context test_effect_context.cpp)
target_link_libraries(test_effect_context GTest::gtest_main)
gtest_discover_tests(test_effect_context)

# ── CTest configuration ────────────────────────────────────────────────────

# Run all ctest suites
include(GoogleTest)

# Optional: add pytest as a ctest item (requires Python + pytest installed)
find_program(PYTEST pytest)
if(PYTEST)
    add_test(
        NAME test_fft_analysis_python
        COMMAND ${PYTEST} "${CMAKE_CURRENT_SOURCE_DIR}/test_fft_analysis.py" -v
    )
endif()
