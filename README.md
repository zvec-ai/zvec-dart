# Zvec Dart SDK

**Dart/Flutter FFI plugin for [Zvec](https://github.com/alibaba/zvec) — a lightweight, lightning-fast, in-process vector database by Alibaba.**

[中文文档](README_zh.md)

---

## Features

- Synchronous & asynchronous vector operations via `dart:ffi`
- Android (`arm64-v8a`) and iOS (`arm64`) support
- Prebuilt native libraries auto-downloaded from GitHub Releases at build time
- Zero manual native compilation for end users

## Installation

```bash
flutter pub add zvec
```

Or add to `pubspec.yaml`:

```yaml
dependencies:
  zvec: ^0.1.6
```

---

## Quick Start

```dart
import 'package:zvec/zvec.dart';

Zvec.initialize();
print('Zvec version: ${Zvec.version}');

final schema = CollectionSchema(name: 'demo', fields: [
  FieldSchema.vector('embedding', dimension: 128),
  FieldSchema.string('title'),
]);

final collection = Collection.createAndOpen('/path/to/db', schema);
// insert, query, fetch ...
collection.close();
Zvec.shutdown();
```

---

## How Native Libraries Are Distributed

Native libraries are **NOT bundled in the pub.dev package**. They are automatically downloaded from GitHub Releases during the build process:

| Platform | Mechanism | Trigger |
|----------|-----------|---------|
| Android | Gradle task `downloadZvecNativeLibs` in `build.gradle` | `flutter build apk` / `flutter run` |
| iOS | `prepare_command` (curl + unzip) in `zvec.podspec` | `pod install` |

---

## Development Guide

The following sections are for SDK developers who need to build from source.

### Prerequisites

| Tool | Min Version | Install |
|------|-------------|---------|
| Flutter | >= 3.3.0 | https://docs.flutter.dev/get-started/install |
| Dart SDK | >= 3.11.3 | Bundled with Flutter |
| Android SDK | API 21+ | Android Studio → SDK Manager |
| Android NDK | 27.x+ | Android Studio → SDK Manager → SDK Tools |
| CMake | >= 3.10 | Android Studio → SDK Manager → SDK Tools |
| Xcode | >= 15.0 | Mac App Store (iOS only) |
| CocoaPods | >= 1.15 | `sudo gem install cocoapods` |

```bash
flutter doctor
flutter --version
```

### Step 1: Clone the Repository

```bash
git clone --recursive <your-repo-url> zvec-dart
cd zvec-dart

# If you forgot --recursive:
git submodule update --init --recursive
```

> The zvec C source is integrated as a git submodule at `third_party/zvec/`.

### Step 2: Install Dependencies

```bash
flutter pub get
cd example && flutter pub get && cd ..
```

### Step 3: Build Native Libraries

#### All Platforms

```bash
bash scripts/build_all.sh
```

#### Android Only

```bash
# arm64-v8a (recommended, covers most devices)
bash scripts/build_android.sh arm64-v8a

# armeabi-v7a (older 32-bit devices)
bash scripts/build_android.sh armeabi-v7a
```

Output: `android/src/main/jniLibs/<abi>/libzvec.so`

> Build process: host protoc → NDK cross-compile zvec → copy .so to jniLibs

#### iOS Only

```bash
# Device (arm64)
bash scripts/build_ios.sh OS

# Apple Silicon Simulator (optional)
bash scripts/build_ios.sh SIMULATORARM64
```

Output: `ios/zvec.framework/` (dynamic framework)

### Step 4: Run Tests

```bash
flutter test test/zvec_test.dart
```

### Step 5: Run the Example App

#### Android

```bash
cd example
flutter devices              # list available devices
flutter run -d <device-id>   # run on device or emulator
```

#### iOS

```bash
cd example
cd ios && pod install && cd ..
flutter run -d <simulator-id>

# Or open in Xcode
open ios/Runner.xcworkspace
```

### Step 6: Regenerate FFI Bindings (Optional)

When upstream zvec C API changes:

```bash
dart run ffigen
```

---

## Project Structure

```
zvec-dart/
├── third_party/
│   └── zvec/                          # git submodule → alibaba/zvec
├── scripts/
│   ├── build_all.sh                   # Build all platforms
│   ├── build_android.sh               # Build Android native lib
│   └── build_ios.sh                   # Build iOS native lib
├── lib/
│   ├── zvec.dart                      # Public API exports
│   └── src/
│       ├── zvec_bindings.dart         # Auto-generated FFI bindings (ffigen)
│       ├── zvec_library.dart          # Dynamic library loader
│       ├── types.dart                 # Enums: DataType, IndexType, MetricType ...
│       ├── errors.dart                # ZvecException, checkError()
│       ├── config.dart                # Zvec.initialize() / shutdown()
│       ├── collection.dart            # Collection (core CRUD class)
│       ├── collection_schema.dart     # CollectionSchema, FieldSchema
│       ├── doc.dart                   # Doc (document read/write)
│       ├── vector_query.dart          # VectorQuery, GroupByVectorQuery
│       ├── index_params.dart          # Hnsw/IVF/Flat/Invert IndexParams
│       ├── query_params.dart          # Hnsw/IVF/Flat QueryParams
│       ├── collection_options.dart    # CollectionOptions
│       └── collection_stats.dart      # CollectionStats
├── src/
│   ├── zvec_plugin.c                  # Empty stub (required by CMake)
│   └── CMakeLists.txt                 # Android NDK build config
├── android/
│   ├── build.gradle                   # Gradle config (auto-downloads libzvec.so)
│   └── src/main/jniLibs/             # Prebuilt .so files (after build)
│       ├── arm64-v8a/libzvec.so
│       └── armeabi-v7a/libzvec.so
├── ios/
│   ├── zvec.podspec                   # CocoaPods config (auto-downloads framework)
│   └── zvec.framework/               # Dynamic framework (after build)
├── example/lib/main.dart              # Example app
├── test/zvec_test.dart                # Unit tests
├── ffigen.yaml                        # ffigen config
└── pubspec.yaml                       # Package config
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `third_party/zvec` is empty | `git submodule update --init --recursive` |
| `DynamicLibrary.open` can't find `libzvec.so` | `bash scripts/build_android.sh arm64-v8a` |
| iOS undefined symbols | Ensure `ios/zvec.framework/` exists, run `bash scripts/build_ios.sh` |
| `dart run ffigen` fails | `brew install llvm` and set `CPATH` |
| Android NDK version mismatch | Set `ANDROID_NDK_HOME` to the correct NDK path |
| protoc build fails | Ensure cmake and C++ compiler are installed |

---

## Release Pipeline

See [.github/workflows/RELEASE_PIPELINE.md](.github/workflows/RELEASE_PIPELINE.md) for the complete release process.

## License

See [LICENSE](LICENSE).
