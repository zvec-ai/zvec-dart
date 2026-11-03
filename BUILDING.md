# Developing the Zvec Dart SDK

[中文版](BUILDING_zh.md)

Use Flutter with Dart 3.4.4 or later in the 3.x series. Install the usual Flutter build tools for your target. Apple builds use Xcode and CocoaPods.

## Set up the repository

```sh
git clone https://github.com/zvec-ai/zvec-dart.git
cd zvec-dart
flutter pub get
(cd example && flutter pub get)
```

## Run the tests

```sh
flutter test test/zvec_test.dart   # Pure Dart
bash scripts/run_tests.sh         # Includes native FFI tests
```

The test script fetches the host SDK on macOS and Linux. For Windows or to test a specific 0.8.0 library, set `ZVEC_LIBRARY_PATH` to its absolute path when running `flutter test`. The native suite checks the engine version, writes and reads collections, runs vector queries and exercises Chinese FTS with the embedded dictionary.

## Run the Flutter example

```sh
cd example
flutter create --platforms=macos .    # Use your target's platform name
flutter run -d <device-id>
```

Generate the runner once for a platform missing from the checkout. In the Apple Podfile and Runner project, set the deployment target to iOS 14.0 or macOS 11.0 or later. During a Flutter build, Gradle, CocoaPods or CMake fetches the official SDK archive and verifies its pinned SHA-256 digest. `ZVEC_SDK_CACHE` can point to a shared directory of verified archives. [Platform requirements](PLATFORM_SUPPORT.md)

## Update the C API bindings

The SDK tag, archive names and checksums are pinned in [the release manifest](tool/zvec_sdk.json). After updating the manifest, generate the Dart bindings from the matching release header using libclang and the project's ffigen dependency.

```sh
dart tool/fetch_zvec.dart --headers
dart run ffigen --config ffigen.yaml
```

To fetch a full SDK for manual inspection, choose a target key from the manifest and an empty output directory.

```sh
dart tool/fetch_zvec.dart --target linux-amd64 --output build/zvec-sdk/linux-amd64
```

## Check the pub package

```sh
dart pub publish --dry-run
```

For release verification, run the manual dry run in the [release workflow](.github/workflows/1-build-and-release.yml).

```sh
gh workflow run 1-build-and-release.yml --ref main -f version=v0.8.0
```
