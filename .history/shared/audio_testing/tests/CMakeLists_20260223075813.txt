cmake_minimum_required(VERSION 3.18)
project(audio_testing_tests CXX)

# ── GoogleTest via FetchContent ───────────────────────────────────────────────
include(FetchContent)

FetchContent_Declare(
    googletest
    GIT_REPOSITORY https://github.com/google/googletest.git
    GIT_TAG        v1.14.0
    GIT_SHALLOW    ON
)
# Keep GoogleTest from overriding the parent project's compiler/linker settings
# on Windows.
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(googletest)

include(GoogleTest)

# ── audio_testing static library (built from ../src/) ────────────────────────
# Pull in the library target so tests can link against it.  Using a separate
# binary directory avoids collisions if this CMakeLists.txt is built
# standalone rather than as part of the top-level tree.
add_subdirectory(
    ${CMAKE_CURRENT_SOURCE_DIR}/../src
    ${CMAKE_CURRENT_BINARY_DIR}/audio_testing_src
)

# ── Common compile options ────────────────────────────────────────────────────
# All test executables use these settings.
set(AT_TEST_COMPILE_OPTIONS
    -Wall
    -Wextra
    -Wpedantic
    -Wno-unused-parameter
)

if(CMAKE_BUILD_TYPE STREQUAL "Debug" AND NOT ANDROID)
    list(APPEND AT_TEST_COMPILE_OPTIONS
        -fsanitize=address,undefined
    )
    set(AT_TEST_LINK_OPTIONS -fsanitize=address,undefined)
endif()

# ── test_sine_generator ───────────────────────────────────────────────────────
add_executable(test_sine_generator
    test_sine_generator.cpp
)

target_compile_features(test_sine_generator PRIVATE cxx_std_17)
target_compile_options(test_sine_generator  PRIVATE ${AT_TEST_COMPILE_OPTIONS})
if(AT_TEST_LINK_OPTIONS)
    target_link_options(test_sine_generator PRIVATE ${AT_TEST_LINK_OPTIONS})
endif()

target_link_libraries(test_sine_generator
    PRIVATE
        audio_testing
        GTest::gtest_main
)

gtest_discover_tests(test_sine_generator
    PROPERTIES TIMEOUT 30
)

# ── test_frequency_validator ─────────────────────────────────────────────────
add_executable(test_frequency_validator
    test_frequency_validator.cpp
)

target_compile_features(test_frequency_validator PRIVATE cxx_std_17)
target_compile_options(test_frequency_validator  PRIVATE ${AT_TEST_COMPILE_OPTIONS})
if(AT_TEST_LINK_OPTIONS)
    target_link_options(test_frequency_validator PRIVATE ${AT_TEST_LINK_OPTIONS})
endif()

target_link_libraries(test_frequency_validator
    PRIVATE
        audio_testing
        GTest::gtest_main
)

# FrequencyValidator performs O(N²) DFT: increase timeout for Debug+ASAN.
gtest_discover_tests(test_frequency_validator
    PROPERTIES TIMEOUT 120
)
