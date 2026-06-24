# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(zvec_library VERSION 0.1.0 LANGUAGES C)

# =============================================================================
# Zvec FFI Plugin — Android native library integration
#
# The prebuilt libzvec.so is loaded at runtime via DynamicLibrary.open().
# It must be placed in the correct jniLibs directory BEFORE building:
#
#   android/src/main/jniLibs/<abi>/libzvec.so
#
# To build the prebuilt library from the git submodule:
#   bash scripts/build_android.sh arm64-v8a
#   bash scripts/build_android.sh armeabi-v7a
#   bash scripts/build_android.sh x86_64
#
# Or build all at once:
#   bash scripts/build_all.sh
# =============================================================================

# Create a thin stub library that Flutter's build system expects.
# The actual zvec symbols are in the prebuilt libzvec.so shipped via jniLibs.
add_library(zvec_plugin SHARED "zvec_plugin.c")

set_target_properties(zvec_plugin PROPERTIES
  OUTPUT_NAME "zvec_plugin"
)

target_compile_definitions(zvec_plugin PUBLIC DART_SHARED_LIB)

if (ANDROID)
  # Support Android 15 16k page size
  target_link_options(zvec_plugin PRIVATE "-Wl,-z,max-page-size=16384")
  target_link_libraries(zvec_plugin PRIVATE dl log)
endif()
