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
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'errors.dart';
import 'fts_query.dart';
import 'query_params.dart';
import 'zvec_bindings.dart';
import 'zvec_library.dart';

ZvecBindings get _b => ZvecLibrary.bindings;

/// A vector similarity query.
///
/// Example:
/// ```dart
/// final query = VectorQuery(
///   fieldName: 'embedding',
///   vector: Float32List.fromList([0.1, 0.2, 0.3, 0.4]),
///   topk: 10,
/// );
/// final results = collection.query(query);
/// ```
class VectorQuery {
  /// Create a vector query.
  ///
  /// - [fieldName]: The vector field to search on.
  /// - [vector]: The query vector (FP32).
  /// - [topk]: Number of results to return (default: 10).
  /// - [filter]: Optional filter expression string.
  /// - [includeVector]: Whether to include vectors in results (default: false).
  /// - [outputFields]: Optional list of fields to include in results.
  /// - [queryParams]: Optional index-specific query parameters.
  /// - [fts]: Deprecated. FTS cannot be combined with vector payloads in a
  ///   single native search query; use [VectorQuery.fts] for FTS-only search.
  /// - [ftsParams]: Deprecated. Use [VectorQuery.fts] for FTS-only search.
  VectorQuery({
    required String fieldName,
    required Float32List vector,
    int topk = 10,
    String? filter,
    bool includeVector = false,
    List<String>? outputFields,
    QueryParams? queryParams,
    FtsQuery? fts,
    FtsQueryParams? ftsParams,
  }) : _ptr = _b.zvec_vector_query_create() {
    if (fts != null || ftsParams != null) {
      _b.zvec_vector_query_destroy(_ptr);
      throw ArgumentError(
        'FTS cannot be combined with a vector payload in one VectorQuery. '
        'Use VectorQuery.fts(...) for FTS-only search.',
      );
    }

    _setFieldName(fieldName);
    _setVector(vector);
    _setTopk(topk);
    _setFilter(filter);
    _setIncludeVector(includeVector);
    _setOutputFields(outputFields);
    if (queryParams != null) {
      _attachVectorQueryParams(_ptr, queryParams);
    }
  }

  /// Create an FTS-only query.
  ///
  /// Native search queries carry either a vector clause or an FTS clause. For
  /// vector + FTS fusion, use multi-query with separate sub-query instances.
  VectorQuery.fts({
    required String fieldName,
    required FtsQuery fts,
    int topk = 10,
    String? filter,
    bool includeVector = false,
    List<String>? outputFields,
    FtsQueryParams? ftsParams,
  }) : _ptr = _b.zvec_vector_query_create() {
    _setFieldName(fieldName);
    _setTopk(topk);
    _setFilter(filter);
    _setIncludeVector(includeVector);
    _setOutputFields(outputFields);
    checkError(_b.zvec_vector_query_set_fts(_ptr, fts.nativePtr));
    if (ftsParams != null) {
      _attachFtsQueryParams(_ptr, ftsParams);
    }
  }

  final Pointer<zvec_vector_query_t> _ptr;

  /// The native pointer for internal use.
  Pointer<zvec_vector_query_t> get nativePtr => _ptr;

  void _setFieldName(String fieldName) {
    final namePtr = fieldName.toNativeUtf8().cast<Char>();
    try {
      checkError(_b.zvec_vector_query_set_field_name(_ptr, namePtr));
    } finally {
      calloc.free(namePtr);
    }
  }

  void _setVector(Float32List vector) {
    final dataPtr = calloc<Float>(vector.length);
    try {
      for (var i = 0; i < vector.length; i++) {
        dataPtr[i] = vector[i];
      }
      checkError(
        _b.zvec_vector_query_set_query_vector(
          _ptr,
          dataPtr.cast(),
          vector.length * sizeOf<Float>(),
        ),
      );
    } finally {
      calloc.free(dataPtr);
    }
  }

  void _setTopk(int topk) {
    checkError(_b.zvec_vector_query_set_topk(_ptr, topk));
  }

  void _setFilter(String? filter) {
    if (filter != null) {
      final filterPtr = filter.toNativeUtf8().cast<Char>();
      try {
        checkError(_b.zvec_vector_query_set_filter(_ptr, filterPtr));
      } finally {
        calloc.free(filterPtr);
      }
    }
  }

  void _setIncludeVector(bool includeVector) {
    checkError(_b.zvec_vector_query_set_include_vector(_ptr, includeVector));
  }

  void _setOutputFields(List<String>? outputFields) {
    if (outputFields != null && outputFields.isNotEmpty) {
      final fieldsPtr = calloc<Pointer<Char>>(outputFields.length);
      final nativePtrs = <Pointer<Utf8>>[];
      try {
        for (var i = 0; i < outputFields.length; i++) {
          final p = outputFields[i].toNativeUtf8();
          nativePtrs.add(p);
          fieldsPtr[i] = p.cast();
        }
        checkError(
          _b.zvec_vector_query_set_output_fields(
            _ptr,
            fieldsPtr,
            outputFields.length,
          ),
        );
      } finally {
        for (final p in nativePtrs) {
          calloc.free(p);
        }
        calloc.free(fieldsPtr);
      }
    }
  }

  /// Destroy the native query.
  void destroy() {
    _b.zvec_vector_query_destroy(_ptr);
  }
}

void _attachVectorQueryParams(
  Pointer<zvec_vector_query_t> queryPtr,
  QueryParams queryParams,
) {
  if (queryParams is HnswQueryParams) {
    final cloned = queryParams.cloneNativePtr();
    var transferred = false;
    try {
      checkError(_b.zvec_vector_query_set_hnsw_params(queryPtr, cloned));
      transferred = true;
    } finally {
      if (!transferred) queryParams.destroyNativePtr(cloned);
    }
  } else if (queryParams is IVFQueryParams) {
    final cloned = queryParams.cloneNativePtr();
    var transferred = false;
    try {
      checkError(_b.zvec_vector_query_set_ivf_params(queryPtr, cloned));
      transferred = true;
    } finally {
      if (!transferred) queryParams.destroyNativePtr(cloned);
    }
  } else if (queryParams is FlatQueryParams) {
    final cloned = queryParams.cloneNativePtr();
    var transferred = false;
    try {
      checkError(_b.zvec_vector_query_set_flat_params(queryPtr, cloned));
      transferred = true;
    } finally {
      if (!transferred) queryParams.destroyNativePtr(cloned);
    }
  } else {
    throw ArgumentError('Unsupported vector query params: $queryParams');
  }
}

void _attachFtsQueryParams(
  Pointer<zvec_vector_query_t> queryPtr,
  FtsQueryParams queryParams,
) {
  final cloned = queryParams.cloneNativePtr();
  var transferred = false;
  try {
    checkError(_b.zvec_vector_query_set_fts_params(queryPtr, cloned));
    transferred = true;
  } finally {
    if (!transferred) queryParams.destroyNativePtr(cloned);
  }
}

void _attachGroupByQueryParams(
  Pointer<zvec_group_by_vector_query_t> queryPtr,
  QueryParams queryParams,
) {
  if (queryParams is HnswQueryParams) {
    final cloned = queryParams.cloneNativePtr();
    var transferred = false;
    try {
      checkError(
        _b.zvec_group_by_vector_query_set_hnsw_params(queryPtr, cloned),
      );
      transferred = true;
    } finally {
      if (!transferred) queryParams.destroyNativePtr(cloned);
    }
  } else if (queryParams is IVFQueryParams) {
    final cloned = queryParams.cloneNativePtr();
    var transferred = false;
    try {
      checkError(
        _b.zvec_group_by_vector_query_set_ivf_params(queryPtr, cloned),
      );
      transferred = true;
    } finally {
      if (!transferred) queryParams.destroyNativePtr(cloned);
    }
  } else if (queryParams is FlatQueryParams) {
    final cloned = queryParams.cloneNativePtr();
    var transferred = false;
    try {
      checkError(
        _b.zvec_group_by_vector_query_set_flat_params(queryPtr, cloned),
      );
      transferred = true;
    } finally {
      if (!transferred) queryParams.destroyNativePtr(cloned);
    }
  } else {
    throw ArgumentError('Unsupported group-by query params: $queryParams');
  }
}

/// A grouped vector similarity query.
///
/// Returns results grouped by a specified field.
class GroupByVectorQuery {
  /// Create a grouped vector query.
  ///
  /// - [fieldName]: The vector field to search on.
  /// - [vector]: The query vector (FP32).
  /// - [groupByFieldName]: The field to group results by.
  /// - [groupCount]: Maximum number of groups (default: 10).
  /// - [groupTopk]: Maximum results per group (default: 1).
  /// - [filter]: Optional filter expression string.
  /// - [includeVector]: Whether to include vectors in results.
  /// - [outputFields]: Optional list of fields to include in results.
  /// - [queryParams]: Optional index-specific query parameters.
  GroupByVectorQuery({
    required String fieldName,
    required Float32List vector,
    required String groupByFieldName,
    int groupCount = 10,
    int groupTopk = 1,
    String? filter,
    bool includeVector = false,
    List<String>? outputFields,
    QueryParams? queryParams,
  }) : _ptr = _b.zvec_group_by_vector_query_create() {
    // Set field name
    final namePtr = fieldName.toNativeUtf8().cast<Char>();
    try {
      checkError(_b.zvec_group_by_vector_query_set_field_name(_ptr, namePtr));
    } finally {
      calloc.free(namePtr);
    }

    // Set group by field name
    final gbPtr = groupByFieldName.toNativeUtf8().cast<Char>();
    try {
      checkError(
        _b.zvec_group_by_vector_query_set_group_by_field_name(_ptr, gbPtr),
      );
    } finally {
      calloc.free(gbPtr);
    }

    // Set vector data
    final dataPtr = calloc<Float>(vector.length);
    try {
      for (var i = 0; i < vector.length; i++) {
        dataPtr[i] = vector[i];
      }
      checkError(
        _b.zvec_group_by_vector_query_set_query_vector(
          _ptr,
          dataPtr.cast(),
          vector.length * sizeOf<Float>(),
        ),
      );
    } finally {
      calloc.free(dataPtr);
    }

    // Set group parameters
    checkError(_b.zvec_group_by_vector_query_set_group_count(_ptr, groupCount));
    checkError(_b.zvec_group_by_vector_query_set_group_topk(_ptr, groupTopk));

    // Set filter
    if (filter != null) {
      final filterPtr = filter.toNativeUtf8().cast<Char>();
      try {
        checkError(_b.zvec_group_by_vector_query_set_filter(_ptr, filterPtr));
      } finally {
        calloc.free(filterPtr);
      }
    }

    // Set include vector
    checkError(
      _b.zvec_group_by_vector_query_set_include_vector(_ptr, includeVector),
    );

    // Set output fields
    if (outputFields != null && outputFields.isNotEmpty) {
      final fieldsPtr = calloc<Pointer<Char>>(outputFields.length);
      final nativePtrs = <Pointer<Utf8>>[];
      try {
        for (var i = 0; i < outputFields.length; i++) {
          final p = outputFields[i].toNativeUtf8();
          nativePtrs.add(p);
          fieldsPtr[i] = p.cast();
        }
        checkError(
          _b.zvec_group_by_vector_query_set_output_fields(
            _ptr,
            fieldsPtr,
            outputFields.length,
          ),
        );
      } finally {
        for (final p in nativePtrs) {
          calloc.free(p);
        }
        calloc.free(fieldsPtr);
      }
    }

    // Set query params
    if (queryParams != null) {
      _attachGroupByQueryParams(_ptr, queryParams);
    }
  }

  final Pointer<zvec_group_by_vector_query_t> _ptr;

  /// The native pointer for internal use.
  Pointer<zvec_group_by_vector_query_t> get nativePtr => _ptr;

  /// Destroy the native query.
  void destroy() {
    _b.zvec_group_by_vector_query_destroy(_ptr);
  }
}
