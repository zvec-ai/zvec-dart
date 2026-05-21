<p align="right">
  <a href="./README.md">English</a> | 中文
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://zvec.oss-cn-hongkong.aliyuncs.com/logo/github_log_2.svg" />
    <img src="https://zvec.oss-cn-hongkong.aliyuncs.com/logo/github_logo_1.svg" height="80" alt="Zvec" />
  </picture>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/flutter/flutter-original.svg" height="64" alt="Flutter" />
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/dart/dart-original.svg" height="64" alt="Dart" />
</p>

<p align="center">
  <strong>面向 Dart &amp; Flutter 的高性能进程内向量数据库 — 由阿里巴巴开源的 <a href="https://github.com/alibaba/zvec">Zvec</a> 提供动力。</strong>
</p>

<p align="center">
  <a href="https://pub.dev/packages/zvec"><img src="https://img.shields.io/pub/v/zvec.svg?label=pub.dev&logo=dart" alt="pub.dev"/></a>
  <a href="https://pub.dev/packages/zvec"><img src="https://img.shields.io/pub/points/zvec?logo=dart" alt="Pub Points"/></a>
  <a href="https://github.com/zvec-ai/zvec-dart/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-Apache%202.0-blue.svg" alt="License"/></a>
  <a href="#"><img src="https://img.shields.io/badge/Flutter-%E2%89%A53.3.0-02569B?logo=flutter&logoColor=white" alt="Flutter"/></a>
  <a href="#"><img src="https://img.shields.io/badge/Dart-%E2%89%A53.11.3-0175C2?logo=dart&logoColor=white" alt="Dart"/></a>
  <a href="#"><img src="https://img.shields.io/badge/platform-Android%20%7C%20iOS-3DDC84" alt="Platforms"/></a>
  <a href="https://github.com/zvec-ai/zvec-dart/actions/workflows/2-test.yml"><img src="https://github.com/zvec-ai/zvec-dart/actions/workflows/2-test.yml/badge.svg?branch=main" alt="Test"/></a>
</p>

---

**Zvec Dart SDK** 通过 `dart:ffi` 把阿里巴巴开源的 [Zvec](https://github.com/alibaba/zvec) 向量引擎搬到了移动端 —— 没有服务、没有 IPC，只有一个动态库直接跑在你 App 的进程里。让端侧的语义检索、RAG、推荐、相似度计算等能力都拥有毫秒级延迟。

## 💫 特性

- **🚀 原生级速度** — 直连久经考验的 C++ 引擎，无 method channel、无 isolate 序列化开销。
- **📱 移动优先** — 提供 **Android** (`arm64-v8a`) 与 **iOS** (`arm64`) 预编译产物。
- **☁️ 安装零摩擦** — 原生库在构建时自动从 GitHub Releases 拉取，pub.dev 包体积保持精简。
- **🧠 丰富的向量能力** — HNSW / IVF / Flat / 倒排索引，支持混合过滤、Top-K 与 Group-By 查询。
- **🔒 持久化存储** — WAL 写前日志 + 原子刷盘，App 重启后数据依旧在。
- **🎯 地道的 Dart API** — 强类型 schema、异常驱动的错误处理、同步式调用。

## 📦 安装

```bash
flutter pub add zvec
```

或在 `pubspec.yaml` 中添加：

```yaml
dependencies:
  zvec: ^0.4.0
```

> **平台支持**
>
> | 平台    | 架构                    | 分发方式                                    |
> | ------- | ----------------------- | ------------------------------------------- |
> | Android | arm64-v8a                | Gradle 任务 `downloadZvecNativeLibs`        |
> | iOS     | arm64（真机）            | CocoaPods `prepare_command`（curl + unzip） |

## ⚡ 快速开始

```dart
import 'dart:typed_data';
import 'package:zvec/zvec.dart';

void main() {
  // 1. 初始化引擎
  Zvec.initialize();
  print('Zvec ${Zvec.version}');

  // 2. 定义 Schema：4 维 FP32 向量字段 + 一个字符串字段
  final schema = CollectionSchema(name: 'demo', fields: [
    VectorSchema('embedding', 4, indexParams: HnswIndexParams()),
    FieldSchema(name: 'title', dataType: DataType.string),
  ]);

  // 3. 创建并打开 Collection
  final collection = Collection.createAndOpen('/tmp/zvec_demo', schema);

  // 4. 写入文档
  final docs = [
    Doc(id: 'doc_1')
      ..setField('title', 'hello')
      ..setVector('embedding', Float32List.fromList([0.1, 0.2, 0.3, 0.4])),
    Doc(id: 'doc_2')
      ..setField('title', 'world')
      ..setVector('embedding', Float32List.fromList([0.2, 0.3, 0.4, 0.1])),
  ];
  collection.insert(docs);
  for (final d in docs) d.destroy();

  // 5. 构建索引
  collection.optimize();

  // 6. 向量检索 —— 按相似度返回 Top-K
  final query = VectorQuery(
    fieldName: 'embedding',
    vector: Float32List.fromList([0.4, 0.3, 0.3, 0.1]),
    topk: 5,
    outputFields: ['title'],
  );
  for (final r in collection.query(query)) {
    print('${r.pk}  score=${r.score}  title=${r.getString('title')}');
  }
  query.destroy();

  // 7. 收尾
  collection.close();
  Zvec.shutdown();
}
```

完整的 Flutter 示例见 [`example/lib/main.dart`](example/lib/main.dart)。

## 🧬 原生库分发方式

原生库**不打包进 pub.dev tarball**，而是在首次构建时自动下载：

| 平台    | 机制                                                          | 触发时机                         |
| ------- | ------------------------------------------------------------- | -------------------------------- |
| Android | `android/build.gradle` 中的 Gradle 任务 `downloadZvecNativeLibs` | `flutter build apk` / `flutter run` |
| iOS     | `ios/zvec.podspec` 中的 `prepare_command`（curl + unzip）        | `pod install`                     |

这样既能让 Dart 包保持精简，也允许原生二进制独立版本演进。

## 🤝 参与贡献

欢迎提交 Issue 与 Pull Request！想定制插件或重新编译原生库？请参考 **[BUILDING_zh.md](BUILDING_zh.md)** 获取开发者构建指南。如果改动涉及底层引擎本身，请到 [上游 zvec 仓库](https://github.com/alibaba/zvec) 提交。

## 📄 许可证

基于 [Apache License 2.0](LICENSE) 开源 —— 与上游 Zvec 保持一致。
