cmake_minimum_required(VERSION 3.10)
project(zvec LANGUAGES CXX)

include("${CMAKE_CURRENT_SOURCE_DIR}/../tool/zvec_desktop.cmake")

if(FLUTTER_TARGET_PLATFORM)
  string(REGEX REPLACE "^linux-" "" ZVEC_PROCESSOR "${FLUTTER_TARGET_PLATFORM}")
else()
  set(ZVEC_PROCESSOR "${CMAKE_SYSTEM_PROCESSOR}")
endif()
zvec_sdk_arch("${ZVEC_PROCESSOR}" ZVEC_ARCH)

# Check the target compiler's libc, including when building with a sysroot.
include(CheckCXXSymbolExists)
check_cxx_symbol_exists(__GLIBC__ "features.h" ZVEC_USES_GLIBC)
if(ZVEC_USES_GLIBC)
  set(ZVEC_TARGET "linux-${ZVEC_ARCH}")
else()
  set(ZVEC_TARGET "linux-musl-${ZVEC_ARCH}")
endif()

zvec_fetch_sdk("${ZVEC_TARGET}" "libzvec_c_api.so" ZVEC_LIBRARY)
set(zvec_bundled_libraries "${ZVEC_LIBRARY}" PARENT_SCOPE)
