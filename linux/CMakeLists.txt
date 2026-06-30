# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. Do not increase this version, as doing so can make the plugin fail
# to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

set(PROJECT_NAME "zvec")
project(${PROJECT_NAME} LANGUAGES CXX)

set(ZVEC_VERSION "0.5.1")
set(ZVEC_GITHUB_BASE "https://github.com/zvec-ai/zvec-dart/releases/download/v${ZVEC_VERSION}")
set(ZVEC_NATIVE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/lib")
set(ZVEC_NATIVE_LIBRARY "${ZVEC_NATIVE_DIR}/libzvec.so")
set(ZVEC_LOCAL_BUILD_LIBRARY "${CMAKE_CURRENT_SOURCE_DIR}/../build/linux/libzvec.so")

file(MAKE_DIRECTORY "${ZVEC_NATIVE_DIR}")
string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" ZVEC_SYSTEM_PROCESSOR)

function(zvec_validate_linux_library_arch LIBRARY_PATH)
  execute_process(
    COMMAND file "${LIBRARY_PATH}"
    OUTPUT_VARIABLE ZVEC_LIBRARY_FILE
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
  )
  if(ZVEC_SYSTEM_PROCESSOR MATCHES "^(x86_64|amd64)$")
    if(NOT ZVEC_LIBRARY_FILE MATCHES "x86-64|x86_64")
      message(FATAL_ERROR "libzvec.so is not x64: ${ZVEC_LIBRARY_FILE}")
    endif()
  elseif(ZVEC_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64)$")
    if(NOT ZVEC_LIBRARY_FILE MATCHES "aarch64|ARM aarch64|arm64")
      message(FATAL_ERROR "libzvec.so is not arm64: ${ZVEC_LIBRARY_FILE}")
    endif()
  else()
    message(FATAL_ERROR "Unsupported Linux architecture for zvec: ${CMAKE_SYSTEM_PROCESSOR}")
  endif()
endfunction()

if(NOT EXISTS "${ZVEC_NATIVE_LIBRARY}")
  if(EXISTS "${ZVEC_LOCAL_BUILD_LIBRARY}")
    message(STATUS "Using locally built zvec native library: ${ZVEC_LOCAL_BUILD_LIBRARY}")
    zvec_validate_linux_library_arch("${ZVEC_LOCAL_BUILD_LIBRARY}")
    file(COPY "${ZVEC_LOCAL_BUILD_LIBRARY}" DESTINATION "${ZVEC_NATIVE_DIR}")
  else()
    if(ZVEC_SYSTEM_PROCESSOR MATCHES "^(x86_64|amd64)$")
      set(ZVEC_NATIVE_ARCH "x64")
    elseif(ZVEC_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64)$")
      message(FATAL_ERROR "Prebuilt zvec for Linux arm64 is not published. Use a source checkout and build it locally with: bash scripts/build_linux.sh")
    else()
      message(FATAL_ERROR "Unsupported Linux architecture for zvec: ${CMAKE_SYSTEM_PROCESSOR}")
    endif()

    set(ZVEC_NATIVE_ZIP_NAME "libzvec-linux-${ZVEC_NATIVE_ARCH}.zip")
    set(ZVEC_NATIVE_ZIP "${CMAKE_CURRENT_BINARY_DIR}/${ZVEC_NATIVE_ZIP_NAME}")
    set(ZVEC_NATIVE_URL "${ZVEC_GITHUB_BASE}/${ZVEC_NATIVE_ZIP_NAME}")

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

zvec_validate_linux_library_arch("${ZVEC_NATIVE_LIBRARY}")

set(zvec_bundled_libraries
  "${ZVEC_NATIVE_LIBRARY}"
  PARENT_SCOPE
)
