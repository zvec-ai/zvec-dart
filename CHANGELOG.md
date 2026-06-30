## 0.5.2

* Add Flutter desktop support for macOS, Linux, and Windows.
* Add desktop native library download, bundling, and release artifact verification.
* Add packaged desktop app smoke tests for native loading, vector queries, and bundled Jieba FTS assets.
* Package the macOS desktop native library as `zvec_native.framework` to avoid framework name collisions.
* Add a manual release dry-run workflow that verifies release artifacts without creating a GitHub Release or publishing to pub.dev.

## 0.5.1

* Bump native zvec engine to v0.5.1.
* No Dart API changes.

## 0.5.0

* Bump native zvec engine to v0.5.0.
* Add FTS support with `FtsQuery`, `FtsQueryParams`, and `FtsIndexParams`.
* Add multi-query hybrid retrieval with `MultiQuery`, `SubQuery`, and rerank strategies.
* Add Jieba tokenizer dictionary configuration via `ConfigData.setJiebaDictDir()` and `Zvec.setDefaultJiebaDictDir()`.
* Register bundled Jieba dictionaries as the native default during package/plugin load.
* Add `VectorQuery.fts(...)` for FTS-only searches.
* Add optional `outputFields` and `includeVector` parameters to `Collection.fetch()` while preserving the default fetch behavior.
* Return detailed per-document write errors through `WriteResult`.
* Remove the deprecated `zvec_doc_validate` binding.

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
