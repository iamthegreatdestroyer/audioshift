cmake_minimum_required(VERSION 3.18)
project(AudioShiftBench CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(FetchContent)
FetchContent_Declare(
    googletest
    URL https://github.com/google/googletest/archive/refs/tags/v1.14.0.zip
    URL_HASH SHA256=1f357c27ca988c3f7c6b4bf68a9395005ac6761f034046e9dde0896e3f498728
)
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(googletest)

add_executable(bench_latency bench_latency.cpp)
target_link_libraries(bench_latency PRIVATE gtest_main)
target_compile_options(bench_latency PRIVATE -O2)
