# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. Do not increase this version, as
# doing so can make the plugin fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "zvec")
project(${PROJECT_NAME} LANGUAGES CXX)

set(ZVEC_VERSION "0.5.2")
set(ZVEC_GITHUB_BASE "https://github.com/zvec-ai/zvec-dart/releases/download/v${ZVEC_VERSION}")
set(ZVEC_NATIVE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/lib")
set(ZVEC_NATIVE_LIBRARY "${ZVEC_NATIVE_DIR}/zvec.dll")
set(ZVEC_LOCAL_BUILD_LIBRARY "${CMAKE_CURRENT_SOURCE_DIR}/../build/windows/zvec.dll")

string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" ZVEC_SYSTEM_PROCESSOR)
if(ZVEC_SYSTEM_PROCESSOR MATCHES "^(x86_64|amd64|x64)$")
  set(ZVEC_NATIVE_ARCH "x64")
else()
  message(FATAL_ERROR "Unsupported Windows architecture for zvec: ${CMAKE_SYSTEM_PROCESSOR}")
endif()

set(ZVEC_NATIVE_ZIP_NAME "libzvec-windows-${ZVEC_NATIVE_ARCH}.zip")
set(ZVEC_NATIVE_ZIP "${CMAKE_CURRENT_BINARY_DIR}/${ZVEC_NATIVE_ZIP_NAME}")
set(ZVEC_NATIVE_URL "${ZVEC_GITHUB_BASE}/${ZVEC_NATIVE_ZIP_NAME}")

file(MAKE_DIRECTORY "${ZVEC_NATIVE_DIR}")

if(NOT EXISTS "${ZVEC_NATIVE_LIBRARY}")
  if(EXISTS "${ZVEC_LOCAL_BUILD_LIBRARY}")
    message(STATUS "Using locally built zvec native library: ${ZVEC_LOCAL_BUILD_LIBRARY}")
    file(COPY "${ZVEC_LOCAL_BUILD_LIBRARY}" DESTINATION "${ZVEC_NATIVE_DIR}")
  else()
    message(STATUS "Downloading zvec native library: ${ZVEC_NATIVE_URL}")
    file(DOWNLOAD
      "${ZVEC_NATIVE_URL}"
      "${ZVEC_NATIVE_ZIP}"
      SHOW_PROGRESS
      TLS_VERIFY ON
      STATUS ZVEC_DOWNLOAD_STATUS
    )
    list(GET ZVEC_DOWNLOAD_STATUS 0 ZVEC_DOWNLOAD_CODE)
    list(GET ZVEC_DOWNLOAD_STATUS 1 ZVEC_DOWNLOAD_MESSAGE)
    if(NOT ZVEC_DOWNLOAD_CODE EQUAL 0)
      message(FATAL_ERROR "Failed to download ${ZVEC_NATIVE_URL}: ${ZVEC_DOWNLOAD_MESSAGE}")
    endif()

    execute_process(
      COMMAND "${CMAKE_COMMAND}" -E tar xf "${ZVEC_NATIVE_ZIP}"
      WORKING_DIRECTORY "${ZVEC_NATIVE_DIR}"
      RESULT_VARIABLE ZVEC_EXTRACT_RESULT
    )
    if(NOT ZVEC_EXTRACT_RESULT EQUAL 0)
      message(FATAL_ERROR "Failed to extract ${ZVEC_NATIVE_ZIP}")
    endif()
  endif()
endif()

if(NOT EXISTS "${ZVEC_NATIVE_LIBRARY}")
  message(FATAL_ERROR "zvec native library not found at ${ZVEC_NATIVE_LIBRARY}")
endif()

set(zvec_bundled_libraries
  "${ZVEC_NATIVE_LIBRARY}"
  PARENT_SCOPE
)
