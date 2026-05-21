# Building Zvec Dart SDK from Source

> 中文版：[BUILDING_zh.md](BUILDING_zh.md)

> ⚠️ End users do **not** need to build from source — `flutter pub add zvec` is enough. The steps below are for SDK contributors who want to hack on the plugin or rebuild the native libraries.

## Prerequisites

| Tool         | Min Version | Where                                                   |
| ------------ | ----------- | ------------------------------------------------------- |
| Flutter      | ≥ 3.3.0     | <https://docs.flutter.dev/get-started/install>          |
| Dart SDK     | ≥ 3.11.3    | bundled with Flutter                                    |
| Android SDK  | API 21+     | Android Studio → SDK Manager                            |
| Android NDK  | 27.x+       | Android Studio → SDK Manager → SDK Tools                |
| CMake        | ≥ 3.10      | Android Studio → SDK Manager → SDK Tools                |
| Xcode        | ≥ 15.0      | Mac App Store (iOS only)                                |
| CocoaPods    | ≥ 1.15      | `sudo gem install cocoapods`                            |

## 1. Clone (with submodules)

```bash
git clone --recursive https://github.com/zvec-ai/zvec-dart.git
cd zvec-dart
# If you forgot --recursive:
git submodule update --init --recursive
```

> Upstream zvec C/C++ source is vendored as a git submodule at `third_party/zvec/`.

## 2. Install Dart deps

```bash
flutter pub get
(cd example && flutter pub get)
```

## 3. Build native libraries

```bash
# All platforms in one go
bash scripts/build_all.sh

# Android only — output: android/src/main/jniLibs/<abi>/libzvec.so
bash scripts/build_android.sh arm64-v8a

# iOS only — output: ios/zvec.framework/
bash scripts/build_ios.sh OS               # device (arm64)
bash scripts/build_ios.sh SIMULATORARM64   # Apple Silicon simulator (optional)
```

## 4. Run tests

```bash
flutter test test/zvec_test.dart
```

## 5. Run the example app

```bash
cd example
flutter run -d <device-id>          # Android or iOS
# iOS first time only:
(cd ios && pod install)
```

## 6. Regenerate FFI bindings (when the upstream C API changes)

```bash
dart run ffigen
```
