# PATH-C Magisk Module — Native Hook Library
#
# Produces:   libaudioshift_effect.so  (Android aarch64)
# Installs:   $MODULE/system/lib64/soundfx/libaudioshift_effect.so
#
# Build with NDK toolchain:
#   cmake -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
#         -DANDROID_ABI=arm64-v8a \
#         -DANDROID_PLATFORM=android-28 \
#         -DCMAKE_BUILD_TYPE=Release \
#         -S path_c_magisk/native \
#         -B path_c_magisk/native/build
#
# Reference: path_c_magisk/build_scripts/build_module.sh

cmake_minimum_required(VERSION 3.22)
project(audioshift_effect CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ─── Paths ───────────────────────────────────────────────────────────────────

# Workspace root relative to this CMakeLists.txt (native/)
set(WORKSPACE_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../..")

# Shared DSP layer
set(SHARED_DSP "${WORKSPACE_ROOT}/shared/dsp")
set(SOUNDTOUCH_SRC "${SHARED_DSP}/third_party/soundtouch/source/SoundTouch")
set(SOUNDTOUCH_INC "${SHARED_DSP}/third_party/soundtouch/include")

# ─── SoundTouch static library ───────────────────────────────────────────────

set(SOUNDTOUCH_SOURCES
    ${SOUNDTOUCH_SRC}/AAFilter.cpp
    ${SOUNDTOUCH_SRC}/FIFOSampleBuffer.cpp
    ${SOUNDTOUCH_SRC}/FIRFilter.cpp
    ${SOUNDTOUCH_SRC}/SoundTouch.cpp
    ${SOUNDTOUCH_SRC}/TDStretch.cpp
    ${SOUNDTOUCH_SRC}/cpu_detect_x86.cpp
    ${SOUNDTOUCH_SRC}/mmx_optimized.cpp
    ${SOUNDTOUCH_SRC}/sse_optimized.cpp
)

add_library(soundtouch_internal STATIC ${SOUNDTOUCH_SOURCES})

target_include_directories(soundtouch_internal PUBLIC
    ${SOUNDTOUCH_INC}
)

target_compile_options(soundtouch_internal PRIVATE
    -O3
    -ffast-math
    -fno-exceptions
)

# ARM-specific optimizations
if(ANDROID_ABI STREQUAL "arm64-v8a")
    target_compile_options(soundtouch_internal PRIVATE
        -march=armv8-a+simd
        -DSOUNDTOUCH_NEON_OPTIMIZED
    )
endif()

# Disable unused SoundTouch features
target_compile_definitions(soundtouch_internal PRIVATE
    SOUNDTOUCH_PREVENT_CLICK_AT_SLEW
    INTEGER_SAMPLES
)

# ─── AudioShift Effect shared library ────────────────────────────────────────

add_library(audioshift_effect SHARED
    audioshift_hook.cpp
)

target_include_directories(audioshift_effect PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}          # audioshift_hook.h
    ${SOUNDTOUCH_INC}                    # SoundTouch.h
    ${SHARED_DSP}/include                # audio_432hz.h  (reference)
)

# Link: SoundTouch (pitch engine) + Android system libs
target_link_libraries(audioshift_effect
    PRIVATE
        soundtouch_internal
        log          # __android_log_print
        # audio      # Not needed; we implement the effect API, not call it
)

# Release flags
target_compile_options(audioshift_effect PRIVATE
    -O3
    -ffast-math
    -fvisibility=hidden     # Only EFFECT_* symbols exported
    -fno-exceptions
    -fno-rtti
)

if(ANDROID_ABI STREQUAL "arm64-v8a")
    target_compile_options(audioshift_effect PRIVATE
        -march=armv8-a+simd
    )
endif()

# Strip all non-exported symbols in release
set_target_properties(audioshift_effect PROPERTIES
    LINK_FLAGS_RELEASE "-Wl,--strip-all"
    OUTPUT_NAME "audioshift_hook"      # → libaudioshift_hook.so
)

# ─── Install into Magisk module directory ────────────────────────────────────

set(MAGISK_MODULE_LIB "${WORKSPACE_ROOT}/path_c_magisk/module/system/lib64/soundfx")

install(TARGETS audioshift_effect
    LIBRARY DESTINATION ${MAGISK_MODULE_LIB}
)

# ─── Status ──────────────────────────────────────────────────────────────────

message(STATUS "AudioShift Effect lib: ${PROJECT_NAME}")
message(STATUS "  ABI:     ${ANDROID_ABI}")
message(STATUS "  NDK:     ${ANDROID_NDK}")
message(STATUS "  Install: ${MAGISK_MODULE_LIB}")
