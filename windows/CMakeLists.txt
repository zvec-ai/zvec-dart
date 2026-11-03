cmake_minimum_required(VERSION 3.14)
project(zvec LANGUAGES CXX)

include("${CMAKE_CURRENT_SOURCE_DIR}/../tool/zvec_desktop.cmake")

if(FLUTTER_TARGET_PLATFORM)
  string(REGEX REPLACE "^windows-" "" ZVEC_PROCESSOR "${FLUTTER_TARGET_PLATFORM}")
elseif(CMAKE_VS_PLATFORM_NAME)
  set(ZVEC_PROCESSOR "${CMAKE_VS_PLATFORM_NAME}")
else()
  set(ZVEC_PROCESSOR "${CMAKE_SYSTEM_PROCESSOR}")
endif()
zvec_sdk_arch("${ZVEC_PROCESSOR}" ZVEC_ARCH)

zvec_fetch_sdk("windows-${ZVEC_ARCH}" "zvec_c_api.dll" ZVEC_LIBRARY)
set(zvec_bundled_libraries "${ZVEC_LIBRARY}" PARENT_SCOPE)
