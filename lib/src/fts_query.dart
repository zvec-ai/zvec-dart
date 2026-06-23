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
import 'zvec_bindings.dart';
import 'zvec_library.dart';

ZvecBindings get _b => ZvecLibrary.bindings;

/// A full-text search (FTS) query payload.
///
/// Use [queryString] for boolean/advanced query expressions,
/// or [matchString] for natural language matching.
///
/// Example:
/// ```dart
/// // Boolean query
/// final fts = FtsQuery(queryString: 'title:flutter AND body:dart');
///
/// // Natural language match
/// final fts = FtsQuery(matchString: '如何使用向量数据库');
/// ```
class FtsQuery {
  /// Create an FTS query.
  ///
  /// - [queryString]: Boolean/advanced query expression.
  /// - [matchString]: Natural language match string.
  ///
  /// At least one of [queryString] or [matchString] should be provided.
  FtsQuery({String? queryString, String? matchString})
    : _ptr = _b.zvec_fts_create() {
    if (queryString != null) {
      final ptr = queryString.toNativeUtf8().cast<Char>();
      try {
        checkError(_b.zvec_fts_set_query_string(_ptr, ptr));
      } finally {
        calloc.free(ptr);
      }
    }
    if (matchString != null) {
      final ptr = matchString.toNativeUtf8().cast<Char>();
      try {
        checkError(_b.zvec_fts_set_match_string(_ptr, ptr));
      } finally {
        calloc.free(ptr);
      }
    }
  }

  final Pointer<zvec_fts_t> _ptr;

  /// The native pointer for internal use.
  Pointer<zvec_fts_t> get nativePtr => _ptr;

  /// Get the query string.
  String? get queryString {
    final ptr = _b.zvec_fts_get_query_string(_ptr);
    if (ptr == nullptr) return null;
    final value = ptr.cast<Utf8>().toDartString();
    return value.isEmpty ? null : value;
  }

  /// Get the match string.
  String? get matchString {
    final ptr = _b.zvec_fts_get_match_string(_ptr);
    if (ptr == nullptr) return null;
    final value = ptr.cast<Utf8>().toDartString();
    return value.isEmpty ? null : value;
  }

  /// Destroy the native FTS query.
  void destroy() {
    _b.zvec_fts_destroy(_ptr);
  }
}
