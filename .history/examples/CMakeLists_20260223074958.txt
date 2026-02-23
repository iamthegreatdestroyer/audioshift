cmake_minimum_required(VERSION 3.22)
project(audioshift_examples CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ── Locate repo root ──────────────────────────────────────────────────────
if(NOT DEFINED REPO_ROOT)
    get_filename_component(REPO_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/.." ABSOLUTE)
endif()

# ── Host-only guard ───────────────────────────────────────────────────────
if(DEFINED ANDROID_ABI)
    message(STATUS "Examples: skipping host-only examples for Android cross-build")
    return()
endif()

# ── Android stub headers (android_mock.h) ─────────────────────────────────
set(ANDROID_MOCK_DIR "${REPO_ROOT}/tests/unit")

# ── audioshift_hook include dir ───────────────────────────────────────────
set(HOOK_INCLUDE_DIR "${REPO_ROOT}/path_c_magisk/native")
set(DSP_INCLUDE_DIR  "${REPO_ROOT}/shared/dsp/include")

# ──────────────────────────────────────────────────────────────────────────
# Example: basic_432hz_usage
# ──────────────────────────────────────────────────────────────────────────
add_executable(basic_432hz_usage basic_432hz_usage.cpp)

target_include_directories(basic_432hz_usage PRIVATE
    ${ANDROID_MOCK_DIR}     # android_mock.h  — must come before hook include
    ${HOOK_INCLUDE_DIR}     # audioshift_hook.h
    ${DSP_INCLUDE_DIR}      # audio_432hz.h, audio_pipeline.h
)

target_compile_definitions(basic_432hz_usage PRIVATE
    AUDIOSHIFT_HOST_BUILD=1
)

target_compile_options(basic_432hz_usage PRIVATE
    -Wall -Wextra -Wpedantic
    $<$<CONFIG:Debug>:-fsanitize=address,undefined>
)
target_link_options(basic_432hz_usage PRIVATE
    $<$<CONFIG:Debug>:-fsanitize=address,undefined>
)

# ── Link against DSP library if available ─────────────────────────────────
set(DSP_LIB "${REPO_ROOT}/shared/dsp/build_host/Release/libaudioshift_dsp.a")
if(EXISTS "${DSP_LIB}")
    target_link_libraries(basic_432hz_usage PRIVATE "${DSP_LIB}" m)
else()
    message(STATUS "Examples: DSP static lib not found; linking math only")
    target_link_libraries(basic_432hz_usage PRIVATE m)
endif()

message(STATUS "Configured example: basic_432hz_usage")
