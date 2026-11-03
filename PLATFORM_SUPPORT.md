# Platform support in 0.8.0

The Flutter plugin uses the C API binaries from the [official Zvec v0.8.0 release](https://github.com/alibaba/zvec/releases/tag/v0.8.0). Gradle, CocoaPods and CMake select the target archive, verify its SHA-256 digest and include the C library in the application.

| Target | Application requirements | Packaging |
| --- | --- | --- |
| Android | Android 9 or newer (API 28), `arm64-v8a` | Gradle stages `libzvec_c_api.so` in the APK/AAB. Use an ARM64 device or emulator. |
| iOS | iOS 14 or newer, arm64 device or Apple Silicon simulator | CocoaPods selects the corresponding slice of `zvec_native.xcframework` and embeds `zvec_native.framework`. |
| macOS | macOS 11 or newer, Apple Silicon or Intel | CocoaPods combines the two upstream dylibs in a universal `zvec_native.framework`. |
| Linux | x64 or arm64, glibc or musl | CMake selects the target architecture and libc, then bundles `libzvec_c_api.so`. |
| Windows | x64 or arm64 | CMake selects the target architecture and bundles `zvec_c_api.dll`. |

CI runs the native FFI suite and the packaged Flutter app on macOS arm64, Linux glibc x64 and arm64, and Windows x64. On mobile it builds the Android arm64 APK and both iOS arm64 variants, then checks the embedded library. Intel macOS, Windows arm64 and Linux musl have upstream binaries and packaging rules. Runtime coverage for these targets depends on testing with a compatible Flutter toolchain. [CI matrix](.github/workflows/2-test.yml)

The Dart SDK constraint is `>=3.4.4 <4.0.0`. For host-side FFI testing, set `ZVEC_LIBRARY_PATH` to the absolute path of the matching 0.8.0 C API library. `Zvec.version` reports the loaded engine version.
