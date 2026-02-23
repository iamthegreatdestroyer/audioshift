# CMake generated Testfile for 
# Source directory: S:/audioshift/shared/dsp/tests
# Build directory: S:/audioshift/shared/dsp/build_host/tests
# 
# This file includes the relevant testing commands required for 
# testing this directory and lists subdirectories to be tested as well.
if(CTEST_CONFIGURATION_TYPE MATCHES "^([Dd][Ee][Bb][Uu][Gg])$")
  add_test([=[dsp_unit_tests]=] "S:/audioshift/shared/dsp/build_host/tests/Debug/test_audio_432hz.exe")
  set_tests_properties([=[dsp_unit_tests]=] PROPERTIES  _BACKTRACE_TRIPLES "S:/audioshift/shared/dsp/tests/CMakeLists.txt;12;add_test;S:/audioshift/shared/dsp/tests/CMakeLists.txt;0;")
elseif(CTEST_CONFIGURATION_TYPE MATCHES "^([Rr][Ee][Ll][Ee][Aa][Ss][Ee])$")
  add_test([=[dsp_unit_tests]=] "S:/audioshift/shared/dsp/build_host/tests/Release/test_audio_432hz.exe")
  set_tests_properties([=[dsp_unit_tests]=] PROPERTIES  _BACKTRACE_TRIPLES "S:/audioshift/shared/dsp/tests/CMakeLists.txt;12;add_test;S:/audioshift/shared/dsp/tests/CMakeLists.txt;0;")
elseif(CTEST_CONFIGURATION_TYPE MATCHES "^([Mm][Ii][Nn][Ss][Ii][Zz][Ee][Rr][Ee][Ll])$")
  add_test([=[dsp_unit_tests]=] "S:/audioshift/shared/dsp/build_host/tests/MinSizeRel/test_audio_432hz.exe")
  set_tests_properties([=[dsp_unit_tests]=] PROPERTIES  _BACKTRACE_TRIPLES "S:/audioshift/shared/dsp/tests/CMakeLists.txt;12;add_test;S:/audioshift/shared/dsp/tests/CMakeLists.txt;0;")
elseif(CTEST_CONFIGURATION_TYPE MATCHES "^([Rr][Ee][Ll][Ww][Ii][Tt][Hh][Dd][Ee][Bb][Ii][Nn][Ff][Oo])$")
  add_test([=[dsp_unit_tests]=] "S:/audioshift/shared/dsp/build_host/tests/RelWithDebInfo/test_audio_432hz.exe")
  set_tests_properties([=[dsp_unit_tests]=] PROPERTIES  _BACKTRACE_TRIPLES "S:/audioshift/shared/dsp/tests/CMakeLists.txt;12;add_test;S:/audioshift/shared/dsp/tests/CMakeLists.txt;0;")
else()
  add_test([=[dsp_unit_tests]=] NOT_AVAILABLE)
endif()
