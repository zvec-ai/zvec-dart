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

import 'dart:ffi';
import 'dart:io';

import 'zvec_bindings.dart';

/// Loads the official zvec C API packaged with the Flutter application.
class ZvecLibrary {
  ZvecLibrary._();

  static final ZvecBindings bindings = ZvecBindings(_openLibrary());

  static DynamicLibrary _openLibrary() {
    final overridePath = Platform.environment['ZVEC_LIBRARY_PATH'];
    if (overridePath != null && overridePath.isNotEmpty) {
      return DynamicLibrary.open(overridePath);
    }

    if (Platform.isAndroid) return DynamicLibrary.open('libzvec_c_api.so');
    final executableDir = File(Platform.resolvedExecutable).parent;
    if (Platform.isIOS || Platform.isMacOS) {
      const framework = 'zvec_native.framework/zvec_native';
      final frameworks = Platform.isIOS
          ? '${executableDir.path}/Frameworks'
          : '${executableDir.parent.path}/Frameworks';
      return _openFirst(['$frameworks/$framework', framework]);
    }
    if (Platform.isLinux) {
      const library = 'libzvec_c_api.so';
      return _openFirst(['${executableDir.path}/lib/$library', library]);
    }
    if (Platform.isWindows) {
      const library = 'zvec_c_api.dll';
      return _openFirst(['${executableDir.path}\\$library', library]);
    }
    throw UnsupportedError(
      'Zvec is not supported on ${Platform.operatingSystem}',
    );
  }

  static DynamicLibrary _openFirst(List<String> candidates) {
    final errors = <String>[];
    for (final candidate in candidates) {
      try {
        return DynamicLibrary.open(candidate);
      } on ArgumentError catch (error) {
        errors.add('$candidate: $error');
      } on OSError catch (error) {
        errors.add('$candidate: $error');
      }
    }

    throw UnsupportedError(
      'Unable to load Zvec native library on ${Platform.operatingSystem}. '
      'Tried: ${candidates.join(', ')}. '
      'Set ZVEC_LIBRARY_PATH to an absolute native library path to override. '
      'Errors: ${errors.join(' | ')}',
    );
  }
}
