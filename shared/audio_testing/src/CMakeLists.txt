# shared/audio_testing/src/CMakeLists.txt
#
# Builds the `audio_testing` static library used by project tests and examples.
# This library is platform-neutral: it compiles on host (Linux/macOS/Windows)
# and cross-compiles for Android via NDK.
#
# Targets exported:
#   audio_testing  — static library with PUBLIC include directory

cmake_minimum_required(VERSION 3.18)

# ── Sources ───────────────────────────────────────────────────────────────────

add_library(audio_testing STATIC
    sine_generator.cpp
    frequency_validator.cpp
)

# ── Compile options ───────────────────────────────────────────────────────────

target_compile_features(audio_testing PUBLIC cxx_std_17)

target_compile_options(audio_testing PRIVATE
    $<$<CXX_COMPILER_ID:GNU,Clang>:
        -Wall
        -Wextra
        -Wno-unused-parameter
    >
    $<$<CXX_COMPILER_ID:MSVC>:
        /W4
        /wd4100  # unreferenced formal parameter
    >
)

# ── Include directories ───────────────────────────────────────────────────────

# PUBLIC: consumers of audio_testing automatically get this directory added to
# their include paths, so "#include <sine_generator.h>" works without extra
# setup.
target_include_directories(audio_testing PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:include/audioshift/testing>
)

# ── Link dependencies ─────────────────────────────────────────────────────────

# Math library (required on Linux; a no-op on Windows/macOS).
find_library(MATH_LIB m)
if(MATH_LIB)
    target_link_libraries(audio_testing PUBLIC ${MATH_LIB})
endif()

# ── Address / undefined-behaviour sanitiser (debug host builds only) ──────────

if(CMAKE_BUILD_TYPE STREQUAL "Debug" AND NOT DEFINED ANDROID_ABI)
    if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
        target_compile_options(audio_testing PUBLIC
            -fsanitize=address,undefined
        )
        target_link_options(audio_testing PUBLIC
            -fsanitize=address,undefined
        )
    endif()
endif()
