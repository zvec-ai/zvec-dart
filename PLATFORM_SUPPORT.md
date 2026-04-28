# Platform Support

This document describes the platform-specific support details for the `zvec` Flutter FFI plugin, including supported architectures, OS version requirements, native library formats, and distribution mechanisms.

## Android

| Item | Details |
|------|---------|
| **Supported ABI** | `arm64-v8a` (64-bit ARM) only |
| **minSdkVersion** | 21 (Android 5.0 Lollipop) |
| **compileSdk** | 36 |
| **NDK version (CI)** | 27.2.12479018 |
| **Native library** | `libzvec.so` (~48 MB, dynamic shared object) |
| **Loading mechanism** | `DynamicLibrary.open('libzvec.so')` via `dart:ffi` |
| **Distribution** | Gradle `downloadZvecNativeLibs` task automatically downloads a zip from GitHub Releases and extracts it to `jniLibs/arm64-v8a/` during `preBuild` |
| **16K page size** | Supported for Android 15 (`-Wl,-z,max-page-size=16384`) |

### Unsupported Android ABIs

| ABI | Reason |
|-----|--------|
| `armeabi-v7a` | Upstream zvec CMake (`cmake/option.cmake`) unconditionally appends `-march=armv8` to CFLAGS, which conflicts with the NDK's `-march=armv7-a` for 32-bit ARM targets, causing thirdparty builds (e.g. lz4) to fail. Re-enable when upstream fixes arch flag handling for armv7. |
| `x86_64` / `x86` | Not currently built or distributed. Can be enabled by adding to `abiFilters` and `zipFiles` in `build.gradle` if needed (e.g. for Android emulators or Chromebooks). |

## iOS

| Item | Details |
|------|---------|
| **Minimum iOS version** | 14.0 |
| **Supported architecture** | `arm64` (physical devices) |
| **Excluded architectures** | `i386` (excluded for simulator builds) |
| **Native library** | `zvec.framework` (~39 MB, dynamic framework) |
| **Framework type** | Dynamic framework (vendored via CocoaPods) |
| **Loading mechanism** | `DynamicLibrary.open('zvec.framework/zvec')` via `dart:ffi` |
| **install_name** | `@rpath/zvec.framework/zvec` |
| **Bundle identifier** | `com.alibaba.zvec` |
| **Distribution** | CocoaPods `prepare_command` downloads `zvec-framework-ios.zip` from GitHub Releases during `pod install` |

### Simulator Support

The build script (`scripts/build_ios.sh`) supports three platform targets:

| Platform parameter | Architecture | SDK |
|--------------------|-------------|-----|
| `OS` (default) | `arm64` | `iphoneos` |
| `SIMULATORARM64` | `arm64` | `iphonesimulator` |
| `SIMULATOR64` | `x86_64` | `iphonesimulator` |

**Note:** CI only builds the `OS` (device) variant. Simulator builds must be done locally:

```bash
# Apple Silicon Mac simulator
bash scripts/build_ios.sh SIMULATORARM64

# Intel Mac simulator
bash scripts/build_ios.sh SIMULATOR64
```

## General Requirements

| Item | Details |
|------|---------|
| **Dart SDK** | `^3.11.3` |
| **Flutter** | `>=3.3.0` |
| **FFI dependency** | `ffi: ^2.1.3` |
| **Plugin type** | FFI Plugin (`ffiPlugin: true`), no Method Channel |
| **CI build environment** | macOS 14 (Apple Silicon), CMake 3.28 |

## Native Library Loading

The native library is loaded at runtime in [`lib/src/zvec_library.dart`](lib/src/zvec_library.dart):

| Platform | Library name |
|----------|-------------|
| Android | `libzvec.so` |
| iOS | `zvec.framework/zvec` |
| macOS | `libzvec.dylib` |
| Linux | `libzvec.so` |
| Windows | `zvec.dll` |

An environment variable `ZVEC_LIBRARY_PATH` can be set to override the library path on any platform. This is useful for host-platform testing where `DYLD_LIBRARY_PATH` is stripped by macOS System Integrity Protection (SIP).

## Build Scripts

| Script | Purpose |
|--------|---------|
| `scripts/build_android.sh [ABI] [API_LEVEL] [BUILD_TYPE]` | Cross-compile `libzvec.so` for Android |
| `scripts/build_ios.sh [PLATFORM] [BUILD_TYPE]` | Cross-compile `zvec.framework` for iOS |
| `scripts/build_all.sh` | Build all platform variants |

### Build Examples

```bash
# Android arm64 Release (default)
bash scripts/build_android.sh

# Android arm64 with explicit parameters
bash scripts/build_android.sh arm64-v8a 21 Release

# iOS device Release (default)
bash scripts/build_ios.sh

# iOS device Debug
bash scripts/build_ios.sh OS Debug

# iOS Apple Silicon simulator
bash scripts/build_ios.sh SIMULATORARM64
```

## Version Information

The plugin has two distinct version numbers:

- **Dart SDK version** (e.g. `0.1.6`): defined in `pubspec.yaml`, `ios/zvec.podspec`, and `android/build.gradle`. This is the version published to pub.dev.
- **Native C engine version** (e.g. `0.3.1`): determined at build time by `git describe --tags` in the `third_party/zvec` submodule. Accessible at runtime via `Zvec.version` which calls the native `zvec_get_version()` function.

## Current Limitations

1. **Android arm64 only** — `armeabi-v7a` is disabled due to upstream CMake arch flag conflicts. Pending upstream fix.
2. **No prebuilt iOS simulator framework** — CI only builds the device (`arm64`) variant. Simulator frameworks must be built locally.
3. **No x86/x86_64 Android** — Not built for Android emulators or Chromebooks. Can be added if needed.
4. **No macOS/Linux/Windows prebuilt binaries** — Desktop platforms are loadable in code but no prebuilt binaries are distributed. Must be built from source for desktop use.
