## 0.4.0

* Bump native zvec engine to v0.4.0.
* Align Dart SDK version with native engine version.
* Docs: fix Quick Start API examples and sync EN/ZH README.

## 0.1.6

* Fix CI: replace fixed sleep with retry loop for pub.dev indexing delay.

## 0.1.5

* Fix CI: iOS verify Podfile platform line was commented out by flutter create.
* Fix CI: fetch submodule tags for correct native version detection.

## 0.1.4

* Fix iOS: remove source_files from podspec to prevent CocoaPods overriding vendored framework.
* Fix Android: remove unsupported armeabi-v7a from abiFilters and download list.
* CI: merge build, publish, and verify into single workflow.

## 0.1.3

* Fix native library download: podspec/build.gradle version now matches pubspec.yaml.

## 0.1.2

* Incremental improvements and bug fixes.

## 0.1.0

* Initial release of Zvec Dart SDK.
* FFI bindings for zvec native vector search engine.
* Support for Android (arm64-v8a) and iOS (arm64) platforms.
* Collection management, document CRUD, and vector search APIs.

## 0.0.1

* TODO: Describe initial release.
