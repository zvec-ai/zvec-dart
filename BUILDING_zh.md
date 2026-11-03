# 开发 Zvec Dart SDK

[English](BUILDING.md)

使用包含 Dart 3.4.4 或更高 3.x 版本的 Flutter SDK，按 Flutter 的要求安装目标平台的构建工具。Apple 平台需要 Xcode 和 CocoaPods。

## 准备仓库

```sh
git clone https://github.com/zvec-ai/zvec-dart.git
cd zvec-dart
flutter pub get
(cd example && flutter pub get)
```

## 运行测试

```sh
flutter test test/zvec_test.dart   # 纯 Dart 测试
bash scripts/run_tests.sh         # 包含原生 FFI 测试
```

测试脚本在 macOS 和 Linux 上会自动下载本机 SDK。在 Windows 上或需要测试指定的 0.8.0 原生库时，将 `ZVEC_LIBRARY_PATH` 设为动态库的绝对路径，再执行 `flutter test`。原生测试覆盖引擎版本、集合读写、向量查询和使用内嵌词典的中文全文检索。

## 运行 Flutter 示例

```sh
cd example
flutter create --platforms=macos .    # 替换成要运行的平台
flutter run -d <device-id>
```

仓库缺少目标平台的示例工程时，先运行一次 `flutter create`。检查生成的 Podfile 和 Runner 工程，iOS 部署目标至少为 14.0，macOS 至少为 11.0。构建时，Gradle、CocoaPods 或 CMake 会下载对应平台的官方 SDK，并按固定的 SHA-256 校验值验证压缩包。可用 `ZVEC_SDK_CACHE` 指向共享缓存目录，复用已校验的压缩包。[平台支持说明](PLATFORM_SUPPORT.md)

## 更新 C API 绑定

[版本清单](tool/zvec_sdk.json)记录了上游版本、各平台压缩包和校验值。更新清单后，使用 libclang 和项目依赖的 ffigen，从同一版 SDK 的头文件生成绑定。

```sh
dart tool/fetch_zvec.dart --headers
dart run ffigen --config ffigen.yaml
```

如需手动检查一个平台的完整 SDK，可从清单中选择目标平台，下载到空目录。

```sh
dart tool/fetch_zvec.dart --target linux-amd64 --output build/zvec-sdk/linux-amd64
```

## 检查 pub 包

```sh
dart pub publish --dry-run
```

发布前可手动运行[发布工作流](.github/workflows/1-build-and-release.yml)中的 dry run。

```sh
gh workflow run 1-build-and-release.yml --ref main -f version=v0.8.0
```
