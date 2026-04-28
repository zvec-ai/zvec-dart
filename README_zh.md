# Zvec Dart SDK

**[Zvec](https://github.com/alibaba/zvec) 的 Dart/Flutter FFI 插件 — 阿里巴巴出品的轻量级、高性能、进程内向量数据库。**

[English](README.md)

---

## 特性

- 通过 `dart:ffi` 实现同步向量操作
- 支持 Android (`arm64-v8a`, `armeabi-v7a`) 和 iOS (`arm64`)
- 预编译原生库在构建时自动从 GitHub Releases 下载
- 终端用户无需手动编译原生代码

## 安装

```bash
flutter pub add zvec
```

或在 `pubspec.yaml` 中添加：

```yaml
dependencies:
  zvec: ^0.1.6
```

---

## 快速开始

```dart
import 'package:zvec/zvec.dart';

Zvec.initialize();
print('Zvec version: ${Zvec.version}');

final schema = CollectionSchema(name: 'demo', fields: [
  VectorSchema('embedding', 128, indexParams: HnswIndexParams()),
  FieldSchema(name: 'title', dataType: DataType.string),
]);

final collection = Collection.createAndOpen('/path/to/db', schema);
// insert, query, fetch ...
collection.close();
Zvec.shutdown();
```

---

## 原生库分发方式

原生库**不包含在 pub.dev 包中**，而是在构建时自动从 GitHub Releases 下载：

| 平台 | 机制 | 触发时机 |
|------|------|---------|
| Android | `build.gradle` 中的 Gradle 任务 `downloadZvecNativeLibs` | `flutter build apk` / `flutter run` |
| iOS | `zvec.podspec` 中的 `prepare_command`（curl + unzip） | `pod install` |

---

## 开发指南

以下内容面向需要从源码构建的 SDK 开发者。

### 前置条件

| 工具 | 最低版本 | 安装方式 |
|------|---------|---------|
| Flutter | >= 3.3.0 | https://docs.flutter.dev/get-started/install |
| Dart SDK | >= 3.11.3 | 随 Flutter 自带 |
| Android SDK | API 21+ | Android Studio → SDK Manager |
| Android NDK | 27.x+ | Android Studio → SDK Manager → SDK Tools |
| CMake | >= 3.10 | Android Studio → SDK Manager → SDK Tools |
| Xcode | >= 15.0 | Mac App Store（仅 iOS） |
| CocoaPods | >= 1.15 | `sudo gem install cocoapods` |

```bash
flutter doctor
flutter --version
```

### 第一步：克隆仓库

```bash
git clone --recursive <your-repo-url> zvec-dart
cd zvec-dart

# 如果忘了 --recursive：
git submodule update --init --recursive
```

> zvec C 源码通过 git submodule 集成在 `third_party/zvec/` 目录下。

### 第二步：安装依赖

```bash
flutter pub get
cd example && flutter pub get && cd ..
```

### 第三步：编译原生库

#### 一键编译所有平台

```bash
bash scripts/build_all.sh
```

#### 单独编译 Android

```bash
# arm64-v8a（推荐，覆盖大多数设备）
bash scripts/build_android.sh arm64-v8a

# armeabi-v7a（较老的 32 位设备）
bash scripts/build_android.sh armeabi-v7a
```

产物路径：`android/src/main/jniLibs/<abi>/libzvec.so`

> 构建流程：宿主机 protoc → NDK 交叉编译 zvec → 复制 .so 到 jniLibs

#### 单独编译 iOS

```bash
# 真机 (arm64)
bash scripts/build_ios.sh OS

# Apple Silicon 模拟器（可选）
bash scripts/build_ios.sh SIMULATORARM64
```

产物路径：`ios/zvec.framework/`（动态框架）

### 第四步：运行测试

```bash
flutter test test/zvec_test.dart
```

### 第五步：运行示例 App

#### Android

```bash
cd example
flutter devices              # 查看可用设备
flutter run -d <device-id>   # 在设备或模拟器上运行
```

#### iOS

```bash
cd example
cd ios && pod install && cd ..
flutter run -d <simulator-id>

# 或用 Xcode 打开
open ios/Runner.xcworkspace
```

### 第六步：重新生成 FFI 绑定（可选）

当上游 zvec C API 发生变更时：

```bash
dart run ffigen
```

---

## 项目结构

```
zvec-dart/
├── third_party/
│   └── zvec/                          # git submodule → alibaba/zvec
├── scripts/
│   ├── build_all.sh                   # 一键编译所有平台
│   ├── build_android.sh               # 编译 Android 原生库
│   ├── build_ios.sh                   # 编译 iOS 原生库
│   ├── build_macos.sh                 # 编译 macOS 原生库
│   └── run_tests.sh                   # 运行测试
├── lib/
│   ├── zvec.dart                      # 公共 API 导出
│   └── src/
│       ├── zvec_bindings.dart         # 自动生成的 FFI 绑定（ffigen）
│       ├── zvec_library.dart          # 动态库加载器
│       ├── types.dart                 # 枚举：DataType, IndexType, MetricType ...
│       ├── errors.dart                # ZvecException, checkError()
│       ├── config.dart                # Zvec.initialize() / shutdown()
│       ├── collection.dart            # Collection（核心 CRUD 类）
│       ├── collection_schema.dart     # CollectionSchema, FieldSchema
│       ├── doc.dart                   # Doc（文档读写）
│       ├── vector_query.dart          # VectorQuery, GroupByVectorQuery
│       ├── index_params.dart          # Hnsw/IVF/Flat/Invert IndexParams
│       ├── query_params.dart          # Hnsw/IVF/Flat QueryParams
│       ├── collection_options.dart    # CollectionOptions
│       └── collection_stats.dart      # CollectionStats
├── src/
│   ├── zvec_plugin.c                  # 空 stub 文件（CMake 需要）
│   └── CMakeLists.txt                 # Android NDK 编译配置
├── android/
│   ├── build.gradle                   # Gradle 配置（自动下载 libzvec.so）
│   └── src/main/jniLibs/             # 预编译 .so 文件（构建后生成）
│       ├── arm64-v8a/libzvec.so
│       └── armeabi-v7a/libzvec.so
├── ios/
│   ├── zvec.podspec                   # CocoaPods 配置（自动下载 framework）
│   └── zvec.framework/               # 动态框架（构建后生成）
├── example/lib/main.dart              # 示例 App
├── test/
│   ├── zvec_test.dart                 # 单元测试
│   └── zvec_native_test.dart          # 原生集成测试
├── ffigen.yaml                        # ffigen 配置
└── pubspec.yaml                       # 包配置
```

---

## 常见问题

| 问题 | 解决方案 |
|------|---------|
| `third_party/zvec` 为空 | `git submodule update --init --recursive` |
| `DynamicLibrary.open` 找不到 `libzvec.so` | `bash scripts/build_android.sh arm64-v8a` |
| iOS undefined symbols | 确保 `ios/zvec.framework/` 存在，运行 `bash scripts/build_ios.sh` |
| `dart run ffigen` 报错 | `brew install llvm` 并设置 `CPATH` |
| Android NDK 版本冲突 | 设置 `ANDROID_NDK_HOME` 指向正确的 NDK 路径 |
| 编译 protoc 失败 | 确保已安装 cmake 和 C++ 编译器 |

---

## 许可证

见 [LICENSE](LICENSE)。
