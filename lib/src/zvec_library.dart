// Copyright 2025-present the zvec project
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'zvec_bindings.dart';

/// Singleton accessor for the Zvec native library bindings.
///
/// Handles platform-specific dynamic library loading:
/// - Android: loads `libzvec.so` via [DynamicLibrary.open]
/// - iOS: loads embedded dynamic framework via
///   [DynamicLibrary.open] (`zvec.framework/zvec`)
class ZvecLibrary {
  ZvecLibrary._();

  static ZvecBindings? _bindings;
  static bool _defaultJiebaDictRegistered = false;

  static const _jiebaDictFiles = ['jieba.dict.utf8', 'hmm_model.utf8'];

  /// Returns the singleton [ZvecBindings] instance.
  ///
  /// Throws [UnsupportedError] on unsupported platforms.
  static ZvecBindings get bindings {
    if (_bindings != null) return _bindings!;
    final bindings = ZvecBindings(_openLibrary());
    _bindings = bindings;
    _registerBundledDefaultJiebaDict(bindings);
    return _bindings!;
  }

  static void _registerBundledDefaultJiebaDict(ZvecBindings bindings) {
    if (_defaultJiebaDictRegistered) return;

    final dictDir = _findBundledJiebaDictDir();
    if (dictDir == null) return;

    final dirPtr = dictDir.path.toNativeUtf8().cast<Char>();
    try {
      bindings.zvec_set_default_jieba_dict_dir(dirPtr);
      _defaultJiebaDictRegistered = true;
    } finally {
      calloc.free(dirPtr);
    }
  }

  static Directory? _findBundledJiebaDictDir() {
    final seen = <String>{};

    for (final root in _candidatePackageRoots()) {
      final absoluteRoot = root.absolute.path;
      if (!seen.add(absoluteRoot)) continue;

      for (final dictDir in _candidateJiebaDictDirs(absoluteRoot)) {
        if (_hasRequiredJiebaDictFiles(dictDir)) {
          return dictDir;
        }
      }
    }

    return null;
  }

  static Iterable<Directory> _candidateJiebaDictDirs(String packageRoot) sync* {
    yield Directory(_join(packageRoot, 'assets/jieba_dict'));
    yield Directory(
      _join(
        packageRoot,
        'third_party/zvec/thirdparty/cppjieba/cppjieba-5.6.7/dict',
      ),
    );
  }

  static Iterable<Directory> _candidatePackageRoots() sync* {
    yield* _ancestors(Directory.current);

    final packageConfigStarts = <Directory>[Directory.current];
    if (Platform.script.scheme == 'file') {
      final scriptDir = File.fromUri(Platform.script).parent;
      yield* _ancestors(scriptDir);
      packageConfigStarts.add(scriptDir);
    }

    for (final start in packageConfigStarts) {
      final root = _findPackageRootFromPackageConfig(start);
      if (root != null) yield root;
    }
  }

  static Iterable<Directory> _ancestors(Directory start) sync* {
    var current = start.absolute;
    while (true) {
      yield current;
      final parent = current.parent;
      if (parent.path == current.path) break;
      current = parent;
    }
  }

  static Directory? _findPackageRootFromPackageConfig(Directory start) {
    for (final dir in _ancestors(start)) {
      final configFile = File(
        _join(dir.path, '.dart_tool/package_config.json'),
      );
      if (!configFile.existsSync()) continue;

      try {
        final config =
            jsonDecode(configFile.readAsStringSync()) as Map<String, Object?>;
        final packages = config['packages'];
        if (packages is! List<Object?>) continue;

        for (final package in packages) {
          if (package is! Map<String, Object?> || package['name'] != 'zvec') {
            continue;
          }

          final rootUriValue = package['rootUri'];
          if (rootUriValue is! String) return null;

          final rootUri = Uri.parse(rootUriValue);
          final resolved = rootUri.isAbsolute
              ? rootUri
              : configFile.parent.uri.resolveUri(rootUri);
          if (resolved.scheme != 'file') return null;
          return Directory.fromUri(resolved);
        }
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  static bool _hasRequiredJiebaDictFiles(Directory dir) {
    for (final fileName in _jiebaDictFiles) {
      final file = File(_join(dir.path, fileName));
      if (!file.existsSync() || file.lengthSync() == 0) {
        return false;
      }
    }
    return true;
  }

  static String _join(String parent, String child) {
    if (parent.endsWith(Platform.pathSeparator)) return '$parent$child';
    return '$parent${Platform.pathSeparator}$child';
  }

  static DynamicLibrary _openLibrary() {
    // Allow overriding the library path via environment variable.
    // This is needed for host-platform testing where DYLD_LIBRARY_PATH
    // is stripped by macOS System Integrity Protection (SIP).
    final overridePath = Platform.environment['ZVEC_LIBRARY_PATH'];
    if (overridePath != null && overridePath.isNotEmpty) {
      return DynamicLibrary.open(overridePath);
    }
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libzvec.so');
    }
    if (Platform.isIOS) {
      // zvec is packaged as an embedded dynamic framework.
      // CocoaPods places it in the app's Frameworks/ directory.
      return DynamicLibrary.open('zvec.framework/zvec');
    }
    // For testing on host platforms (macOS/Linux/Windows)
    if (Platform.isMacOS) {
      return DynamicLibrary.open('libzvec.dylib');
    }
    if (Platform.isLinux) {
      return DynamicLibrary.open('libzvec.so');
    }
    if (Platform.isWindows) {
      return DynamicLibrary.open('zvec.dll');
    }
    throw UnsupportedError(
      'Zvec is not supported on ${Platform.operatingSystem}',
    );
  }
}
