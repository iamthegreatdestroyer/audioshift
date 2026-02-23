cmake_minimum_required(VERSION 3.22)
project(audioshift_dsp CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# SoundTouch source files
file(GLOB SOUNDTOUCH_SRCS
     "third_party/soundtouch/source/SoundTouch/*.cpp")

add_library(soundtouch_internal STATIC ${SOUNDTOUCH_SRCS})
target_include_directories(soundtouch_internal PUBLIC
    third_party/soundtouch/include)

if(MSVC)
    target_compile_options(soundtouch_internal PRIVATE /W4 /O2)
else()
    target_compile_options(soundtouch_internal PRIVATE -Wall -Wextra -O2)
endif()

if(ANDROID)
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64")
        target_compile_options(soundtouch_internal PRIVATE -march=armv8-a+simd)
    endif()
endif()

# Main DSP library
add_library(audioshift_dsp SHARED
    src/audio_432hz.cpp
    src/audio_pipeline.cpp)

target_include_directories(audioshift_dsp PUBLIC include)
target_link_libraries(audioshift_dsp PRIVATE soundtouch_internal)

if(MSVC)
    target_compile_options(audioshift_dsp PRIVATE /W4 /O2)
else()
    target_compile_options(audioshift_dsp PRIVATE -Wall -Wextra -O2)
endif()

# Unit tests (host only)
if(NOT ANDROID)
    add_subdirectory(tests)
endif()
