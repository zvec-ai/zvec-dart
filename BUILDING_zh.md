# 从源码构建 Zvec Dart SDK

> English version: [BUILDING.md](BUILDING.md)

> ⚠️ 终端用户**不需要**从源码构建 —— `flutter pub add zvec` 即可。下面的步骤面向想要修改插件或重新编译原生库的 SDK 贡献者。

## 前置条件

| 工具         | 最低版本    | 安装方式                                                |
| ------------ | ----------- | ------------------------------------------------------- |
| Flutter      | ≥ 3.3.0     | <https://docs.flutter.dev/get-started/install>          |
| Dart SDK     | ≥ 3.11.3    | 随 Flutter 自带                                          |
| Android SDK  | API 21+     | Android Studio → SDK Manager                            |
| Android NDK  | 27.x+       | Android Studio → SDK Manager → SDK Tools                |
| CMake        | ≥ 3.10      | Android Studio → SDK Manager → SDK Tools                |
| Xcode        | ≥ 15.0      | Mac App Store（仅 iOS/macOS 需要）                        |
| CocoaPods    | ≥ 1.15      | `sudo gem install cocoapods`                            |
| Visual Studio| 2022+       | Windows 桌面端构建需要                                   |

## 1. 克隆仓库（含子模块）

```bash
git clone --recursive https://github.com/zvec-ai/zvec-dart.git
cd zvec-dart
# 如果忘了 --recursive：
git submodule update --init --recursive
```

> 上游 zvec 的 C/C++ 源码以 git submodule 形式集成在 `third_party/zvec/`。

## 2. 安装 Dart 依赖

```bash
flutter pub get
(cd example && flutter pub get)
```

## 3. 编译原生库

```bash
# 一键编译当前宿主可构建的目标
bash scripts/build_all.sh

# 只编译 Android —— 产物：android/src/main/jniLibs/<abi>/libzvec.so
bash scripts/build_android.sh arm64-v8a

# 只编译 iOS —— 产物：ios/zvec.framework/
bash scripts/build_ios.sh OS               # 真机 (arm64)
bash scripts/build_ios.sh SIMULATORARM64   # Apple Silicon 模拟器（可选）

# 只编译 macOS 桌面端 —— 产物：macos/zvec.framework/
bash scripts/build_macos.sh

# 只编译 Linux 桌面端 —— 产物：linux/lib/libzvec.so
bash scripts/build_linux.sh

# 只编译 Windows 桌面端 —— 产物：windows/lib/zvec.dll
powershell -ExecutionPolicy Bypass -File scripts/build_windows.ps1
```

## 4. 运行测试

```bash
flutter test test/zvec_test.dart
```

## 5. 运行示例 App

```bash
cd example
flutter run -d <device-id>          # Android、iOS、macOS、Linux 或 Windows
# iOS 首次运行：
(cd ios && pod install)
```

## 6. 重新生成 FFI 绑定（上游 C API 变动时）

```bash
dart run ffigen
```
