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

import 'errors.dart';
import 'zvec_bindings.dart';
import 'zvec_library.dart';

ZvecBindings get _b => ZvecLibrary.bindings;

/// Options for opening or creating a collection.
class CollectionOptions {
  CollectionOptions._();

  Pointer<zvec_collection_options_t>? _ptr;

  /// Create default collection options.
  factory CollectionOptions() {
    final opts = CollectionOptions._();
    opts._ptr = _b.zvec_collection_options_create();
    return opts;
  }

  /// Create from a native pointer. Used internally by Collection.
  factory CollectionOptions.fromNativePtr(
    Pointer<zvec_collection_options_t> ptr,
  ) {
    final opts = CollectionOptions._();
    opts._ptr = ptr;
    return opts;
  }

  Pointer<zvec_collection_options_t> get _nativePtr {
    if (_ptr == null) throw StateError('CollectionOptions has been destroyed');
    return _ptr!;
  }

  /// The native pointer for internal use.
  Pointer<zvec_collection_options_t> get nativePtr => _nativePtr;

  /// Whether memory-mapped I/O is enabled.
  bool get enableMmap => _b.zvec_collection_options_get_enable_mmap(_nativePtr);

  /// Set whether to enable memory-mapped I/O.
  set enableMmap(bool value) {
    checkError(_b.zvec_collection_options_set_enable_mmap(_nativePtr, value));
  }

  /// Maximum buffer size in bytes.
  int get maxBufferSize =>
      _b.zvec_collection_options_get_max_buffer_size(_nativePtr);

  /// Set maximum buffer size in bytes.
  set maxBufferSize(int value) {
    checkError(
      _b.zvec_collection_options_set_max_buffer_size(_nativePtr, value),
    );
  }

  /// Whether the collection is opened in read-only mode.
  bool get readOnly => _b.zvec_collection_options_get_read_only(_nativePtr);

  /// Set whether to open the collection in read-only mode.
  set readOnly(bool value) {
    checkError(_b.zvec_collection_options_set_read_only(_nativePtr, value));
  }

  /// Destroy the native options.
  void destroy() {
    if (_ptr != null) {
      _b.zvec_collection_options_destroy(_ptr!);
      _ptr = null;
    }
  }
}
