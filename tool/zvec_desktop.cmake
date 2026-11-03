# Build rules shared by the Flutter desktop plugins.
function(zvec_sdk_arch processor output_variable)
  string(TOLOWER "${processor}" processor)
  if(processor MATCHES "^(amd64|x86_64|x64)$")
    set(arch "amd64")
  elseif(processor MATCHES "^(arm64|aarch64)$")
    set(arch "arm64")
  else()
    message(FATAL_ERROR "Unsupported architecture for the zvec SDK: ${processor}")
  endif()
  set(${output_variable} "${arch}" PARENT_SCOPE)
endfunction()

function(zvec_fetch_sdk target filename output_variable)
  if(FLUTTER_MANAGED_DIR AND EXISTS "${FLUTTER_MANAGED_DIR}/ephemeral/generated_config.cmake")
    include("${FLUTTER_MANAGED_DIR}/ephemeral/generated_config.cmake")
  endif()
  find_program(ZVEC_DART_EXECUTABLE dart
    HINTS "${FLUTTER_ROOT}/bin/cache/dart-sdk/bin" "$ENV{FLUTTER_ROOT}/bin/cache/dart-sdk/bin"
    NO_CMAKE_FIND_ROOT_PATH)
  if(NOT ZVEC_DART_EXECUTABLE)
    message(FATAL_ERROR "Could not find Dart to download the zvec SDK. Set FLUTTER_ROOT or add Dart to PATH.")
  endif()

  get_filename_component(tool_dir "${CMAKE_CURRENT_SOURCE_DIR}/../tool" ABSOLUTE)
  set(sdk_dir "${CMAKE_CURRENT_BINARY_DIR}/zvec-sdk/${target}")
  set(library "${sdk_dir}/lib/${filename}")
  add_custom_command(
    OUTPUT "${library}"
    COMMAND "${ZVEC_DART_EXECUTABLE}" "${tool_dir}/fetch_zvec.dart"
            --target "${target}" --output "${sdk_dir}"
    COMMAND "${CMAKE_COMMAND}" -E touch_nocreate "${library}"
    DEPENDS "${tool_dir}/fetch_zvec.dart" "${tool_dir}/zvec_sdk.json"
    COMMENT "Preparing zvec SDK for ${target}"
    VERBATIM)
  add_custom_target(zvec_native_sdk ALL DEPENDS "${library}")
  set(${output_variable} "${library}" PARENT_SCOPE)
endfunction()
