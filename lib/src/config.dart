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

import 'package:ffi/ffi.dart';

import 'errors.dart';
import 'types.dart';
import 'zvec_bindings.dart';
import 'zvec_library.dart';

/// Log configuration for the Zvec library.
///
/// Create via [LogConfig.console] or [LogConfig.file] factory constructors.
class LogConfig {
  LogConfig._(this._ptr);

  final Pointer<zvec_log_config_t> _ptr;

  /// Create a console log configuration.
  factory LogConfig.console({LogLevel level = LogLevel.info}) {
    final ptr = ZvecLibrary.bindings.zvec_config_log_create_console(
      zvec_log_level_t.fromValue(level.value),
    );
    return LogConfig._(ptr);
  }

  /// Create a file log configuration.
  factory LogConfig.file({
    LogLevel level = LogLevel.info,
    required String directory,
    String basename = 'zvec',
    int fileSizeMb = 100,
    int overdueDays = 7,
  }) {
    final dirPtr = directory.toNativeUtf8().cast<Char>();
    final namePtr = basename.toNativeUtf8().cast<Char>();
    try {
      final ptr = ZvecLibrary.bindings.zvec_config_log_create_file(
        zvec_log_level_t.fromValue(level.value),
        dirPtr,
        namePtr,
        fileSizeMb,
        overdueDays,
      );
      return LogConfig._(ptr);
    } finally {
      calloc.free(dirPtr);
      calloc.free(namePtr);
    }
  }

  /// Get the native pointer (for internal use by ConfigData).
  Pointer<zvec_log_config_t> get nativePtr => _ptr;

  /// Destroy this log config. Only call if NOT passed to ConfigData
  /// (ConfigData takes ownership).
  void destroy() {
    ZvecLibrary.bindings.zvec_config_log_destroy(_ptr);
  }
}

/// Global configuration data for the Zvec library.
class ConfigData {
  ConfigData._();

  Pointer<zvec_config_data_t>? _ptr;

  /// Create a new configuration data object.
  factory ConfigData() {
    final config = ConfigData._();
    config._ptr = ZvecLibrary.bindings.zvec_config_data_create();
    return config;
  }

  Pointer<zvec_config_data_t> get _nativePtr {
    if (_ptr == null) throw StateError('ConfigData has been destroyed');
    return _ptr!;
  }

  /// Set memory limit in bytes.
  void setMemoryLimit(int bytes) {
    checkError(
      ZvecLibrary.bindings.zvec_config_data_set_memory_limit(_nativePtr, bytes),
    );
  }

  /// Get memory limit in bytes.
  int get memoryLimit =>
      ZvecLibrary.bindings.zvec_config_data_get_memory_limit(_nativePtr);

  /// Set log configuration. Ownership of [logConfig] is transferred.
  void setLogConfig(LogConfig logConfig) {
    checkError(
      ZvecLibrary.bindings.zvec_config_data_set_log_config(
        _nativePtr,
        logConfig.nativePtr,
      ),
    );
  }

  /// Set the number of threads used for query operations.
  void setQueryThreadCount(int count) {
    checkError(
      ZvecLibrary.bindings.zvec_config_data_set_query_thread_count(
        _nativePtr,
        count,
      ),
    );
  }

  /// Get the number of threads used for query operations.
  int get queryThreadCount =>
      ZvecLibrary.bindings.zvec_config_data_get_query_thread_count(_nativePtr);

  /// Set the number of threads used for optimize operations.
  void setOptimizeThreadCount(int count) {
    checkError(
      ZvecLibrary.bindings.zvec_config_data_set_optimize_thread_count(
        _nativePtr,
        count,
      ),
    );
  }

  /// Get the number of threads used for optimize operations.
  int get optimizeThreadCount => ZvecLibrary.bindings
      .zvec_config_data_get_optimize_thread_count(_nativePtr);

  /// Set the FTS brute-force by keys ratio.
  void setFtsBruteForceByKeysRatio(double ratio) {
    checkError(
      ZvecLibrary.bindings.zvec_config_data_set_fts_brute_force_by_keys_ratio(
        _nativePtr,
        ratio,
      ),
    );
  }

  /// Get the FTS brute-force by keys ratio.
  double get ftsBruteForceByKeysRatio => ZvecLibrary.bindings
      .zvec_config_data_get_fts_brute_force_by_keys_ratio(_nativePtr);

  /// Set the Jieba dictionary directory.
  void setJiebaDictDir(String dir) {
    final dirPtr = dir.toNativeUtf8().cast<Char>();
    try {
      checkError(
        ZvecLibrary.bindings.zvec_config_data_set_jieba_dict_dir(
          _nativePtr,
          dirPtr,
        ),
      );
    } finally {
      calloc.free(dirPtr);
    }
  }

  /// Get the Jieba dictionary directory.
  String? get jiebaDictDir {
    final ptr = ZvecLibrary.bindings.zvec_config_data_get_jieba_dict_dir(
      _nativePtr,
    );
    if (ptr == nullptr) return null;
    return ptr.cast<Utf8>().toDartString();
  }

  /// Destroy the native config data.
  void destroy() {
    if (_ptr != null) {
      ZvecLibrary.bindings.zvec_config_data_destroy(_ptr!);
      _ptr = null;
    }
  }
}

/// Top-level Zvec library lifecycle management.
class Zvec {
  Zvec._();

  /// Initialize the Zvec library with optional configuration.
  ///
  /// Must be called before any other Zvec operations.
  /// If [config] is null, default configuration is used.
  /// The [config] is consumed and should not be used after this call.
  static void initialize([ConfigData? config]) {
    final ptr = config?._nativePtr ?? nullptr.cast<zvec_config_data_t>();
    checkError(ZvecLibrary.bindings.zvec_initialize(ptr));
  }

  /// Shut down the Zvec library and release all resources.
  static void shutdown() {
    checkError(ZvecLibrary.bindings.zvec_shutdown());
  }

  /// Check if the library has been initialized.
  static bool get isInitialized => ZvecLibrary.bindings.zvec_is_initialized();

  /// Get the library version string.
  static String get version {
    final ptr = ZvecLibrary.bindings.zvec_get_version();
    return ptr.cast<Utf8>().toDartString();
  }

  /// Get the major version number.
  static int get versionMajor => ZvecLibrary.bindings.zvec_get_version_major();

  /// Get the minor version number.
  static int get versionMinor => ZvecLibrary.bindings.zvec_get_version_minor();

  /// Get the patch version number.
  static int get versionPatch => ZvecLibrary.bindings.zvec_get_version_patch();

  /// Check if the library version is compatible with the given requirements.
  static bool checkVersion(int major, int minor, int patch) =>
      ZvecLibrary.bindings.zvec_check_version(major, minor, patch);

  /// Set the global default Jieba dictionary directory.
  static void setDefaultJiebaDictDir(String dir) {
    final dirPtr = dir.toNativeUtf8().cast<Char>();
    try {
      ZvecLibrary.bindings.zvec_set_default_jieba_dict_dir(dirPtr);
    } finally {
      calloc.free(dirPtr);
    }
  }

  /// Get the global default Jieba dictionary directory.
  static String? get defaultJiebaDictDir {
    final ptr = ZvecLibrary.bindings.zvec_get_default_jieba_dict_dir();
    if (ptr == nullptr) return null;
    return ptr.cast<Utf8>().toDartString();
  }
}
