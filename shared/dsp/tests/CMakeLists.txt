cmake_minimum_required(VERSION 3.22)

# Simple test runner — no external test framework dependency
add_executable(test_audio_432hz
    test_audio_432hz.cpp)

target_link_libraries(test_audio_432hz PRIVATE audioshift_dsp)
target_include_directories(test_audio_432hz PRIVATE
    ${CMAKE_SOURCE_DIR}/include)

enable_testing()
add_test(NAME dsp_unit_tests COMMAND test_audio_432hz)
