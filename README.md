<p align="right">
  English | <a href="./README_zh.md">中文</a>
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/zvec-ai/zvec-dart/main/assets/hero-dark.svg" />
    <img src="https://raw.githubusercontent.com/zvec-ai/zvec-dart/main/assets/hero-light.svg" width="610" alt="Zvec × Flutter + Dart" />
  </picture>
</p>

<p align="center">
  <strong>Lightning-fast, in-process vector database for Dart &amp; Flutter — powered by <a href="https://github.com/alibaba/zvec">Zvec</a>.</strong>
</p>

<p align="center">
  <a href="https://pub.dev/packages/zvec"><img src="https://img.shields.io/pub/v/zvec.svg?label=pub.dev&logo=dart" alt="pub.dev"/></a>
  <a href="https://github.com/zvec-ai/zvec-dart/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-Apache%202.0-blue.svg" alt="License"/></a>
  <a href="#"><img src="https://img.shields.io/badge/Flutter-%E2%89%A53.3.0-02569B?logo=flutter&logoColor=white" alt="Flutter"/></a>
  <a href="#"><img src="https://img.shields.io/badge/Dart-%E2%89%A53.4.4-0175C2?logo=dart&logoColor=white" alt="Dart"/></a>
  <a href="#"><img src="https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Linux%20%7C%20Windows-3DDC84" alt="Platforms"/></a>
  <a href="https://github.com/zvec-ai/zvec-dart/actions/workflows/2-test.yml"><img src="https://github.com/zvec-ai/zvec-dart/actions/workflows/2-test.yml/badge.svg?branch=main" alt="Test"/></a>
</p>

---

**Zvec Dart SDK** brings Alibaba's open-source [Zvec](https://github.com/alibaba/zvec) vector engine to Flutter and Dart via `dart:ffi` — no servers, no IPC, just a single dynamic library running in your app's process. Build on-device and desktop semantic search, RAG, recommendation, and similarity workloads with milliseconds-level latency.

## 💫 Features

- **🚀 Native speed** — Direct FFI calls into a battle-tested C++ engine; no method-channel hops, no isolate marshalling.
- **📱 Mobile + desktop** — Ships prebuilt binaries for **Android**, **iOS**, **macOS**, **Linux**, and **Windows**.
- **☁️ Zero-friction install** — Native libs are auto-fetched from GitHub Releases at build time. Your `pub.dev` package stays slim.
- **🧠 Rich vector ops** — HNSW / IVF / Flat / Inverted indexes, hybrid filters, top-k & group-by queries.
- **🔒 Durable storage** — Write-ahead log, atomic flush, persistent across app restarts.
- **🎯 Idiomatic Dart** — Strongly-typed schema, exception-based error handling, synchronous API.

## 📦 Installation

```bash
flutter pub add zvec
```

Or in `pubspec.yaml`:

```yaml
dependencies:
  zvec: ^0.5.1
```

> **Platform support**
>
> | Platform | Architectures      | Distribution                                 |
> | -------- | ------------------ | -------------------------------------------- |
> | Android  | arm64-v8a          | Gradle task `downloadZvecNativeLibs`          |
> | iOS      | arm64 (device)     | CocoaPods `prepare_command` (curl + unzip)   |
> | macOS    | arm64              | CocoaPods `prepare_command` (curl + unzip)   |
> | Linux    | x64                | Flutter desktop CMake download + bundle      |
> | Windows  | x64                | Flutter desktop CMake download + bundle      |

## ⚡ Quick Start

```dart
import 'dart:typed_data';
import 'package:zvec/zvec.dart';

void main() {
  // 1. Boot the engine
  Zvec.initialize();
  print('Zvec ${Zvec.version}');

  // 2. Define a schema: 4-dim FP32 vector + a string field
  final schema = CollectionSchema(name: 'demo', fields: [
    VectorSchema('embedding', 4, indexParams: HnswIndexParams()),
    FieldSchema(name: 'title', dataType: DataType.string),
  ]);

  // 3. Create & open the collection
  final collection = Collection.createAndOpen('/tmp/zvec_demo', schema);

  // 4. Insert documents
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

  // 5. Build the index
  collection.optimize();

  // 6. Vector search — top-k by cosine similarity
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

  // 7. Clean up
  collection.close();
  Zvec.shutdown();
}
```

A full Flutter demo lives in [`example/lib/main.dart`](example/lib/main.dart).

## 🧬 How Native Libraries Are Distributed

Native libraries are **NOT bundled in the pub.dev tarball** — they're fetched on first build:

| Platform | Mechanism | Trigger |
| -------- | --------- | ------- |
| Android  | Gradle task `downloadZvecNativeLibs` (`android/build.gradle`) | `flutter build apk` / `flutter run` |
| iOS      | `prepare_command` in `ios/zvec.podspec` (curl + unzip)        | `pod install` |
| macOS    | `prepare_command` in `macos/zvec.podspec` (curl + unzip)      | `pod install` |
| Linux    | `linux/CMakeLists.txt` downloads and bundles `libzvec.so`      | `flutter build linux` / `flutter run -d linux` |
| Windows  | `windows/CMakeLists.txt` downloads and bundles `zvec.dll`      | `flutter build windows` / `flutter run -d windows` |

This keeps the Dart package small and lets us version native binaries independently.

## 🤝 Contributing

Issues and pull requests are welcome! Want to hack on the plugin or rebuild the native libraries? See **[BUILDING.md](BUILDING.md)** for the developer setup. For changes that touch the underlying engine, please file them in the [upstream zvec repo](https://github.com/alibaba/zvec) instead.

## 📄 License

Released under the [Apache License 2.0](LICENSE) — same as upstream Zvec.
