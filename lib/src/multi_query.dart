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

/// Rerank strategy for multi-query result fusion.
sealed class RerankStrategy {
  const RerankStrategy();
}

/// Reciprocal Rank Fusion (RRF) rerank strategy.
class RrfRerank extends RerankStrategy {
  /// Create an RRF rerank strategy.
  ///
  /// - [rankConstant]: RRF rank constant (default: 60).
  const RrfRerank({this.rankConstant = 60});

  /// The RRF rank constant parameter.
  final int rankConstant;
}

/// Weighted score fusion rerank strategy.
class WeightedRerank extends RerankStrategy {
  /// Create a weighted rerank strategy.
  ///
  /// - [weights]: Weight for each sub-query (must match sub-query count).
  const WeightedRerank({required this.weights});

  /// Weights for each sub-query.
  final List<double> weights;
}

/// A sub-query component for [MultiQuery].
///
/// Represents either a dense vector search, sparse vector search, or FTS search
/// on a specific field.
class SubQuery {
  /// Create a sub-query.
  ///
  /// - [fieldName]: The field to search on.
  /// - [vector]: Dense query vector (FP32). Provide this, [sparseIndices]+[sparseValues], or [fts].
  /// - [sparseIndices]: Sparse vector indices.
  /// - [sparseValues]: Sparse vector values.
  /// - [fts]: FTS query payload.
  /// - [numCandidates]: Number of candidates to retrieve (default: 100).
  /// - [queryParams]: Optional index-specific query parameters.
  /// - [ftsParams]: Optional FTS query parameters.
  SubQuery({
    required String fieldName,
    Float32List? vector,
    Uint32List? sparseIndices,
    Float32List? sparseValues,
    FtsQuery? fts,
    int numCandidates = 100,
    QueryParams? queryParams,
    FtsQueryParams? ftsParams,
  }) : _ptr = _b.zvec_sub_query_create() {
    if (fts != null &&
        (vector != null || sparseIndices != null || sparseValues != null)) {
      _b.zvec_sub_query_destroy(_ptr);
      throw ArgumentError(
        'A SubQuery can carry either a vector payload or an FTS payload. '
        'Use separate SubQuery instances for vector + FTS fusion.',
      );
    }

    // Set field name
    final namePtr = fieldName.toNativeUtf8().cast<Char>();
    try {
      checkError(_b.zvec_sub_query_set_field_name(_ptr, namePtr));
    } finally {
      calloc.free(namePtr);
    }

    // Set num candidates
    checkError(_b.zvec_sub_query_set_num_candidates(_ptr, numCandidates));

    // Set dense vector
    if (vector != null) {
      final dataPtr = calloc<Float>(vector.length);
      try {
        for (var i = 0; i < vector.length; i++) {
          dataPtr[i] = vector[i];
        }
        checkError(
          _b.zvec_sub_query_set_query_vector(
            _ptr,
            dataPtr.cast(),
            vector.length * sizeOf<Float>(),
          ),
        );
      } finally {
        calloc.free(dataPtr);
      }
    }

    // Set sparse vector
    if (sparseIndices != null && sparseValues != null) {
      assert(
        sparseIndices.length == sparseValues.length,
        'sparseIndices and sparseValues must have the same length',
      );
      final indicesPtr = calloc<Uint32>(sparseIndices.length);
      final valuesPtr = calloc<Float>(sparseValues.length);
      try {
        for (var i = 0; i < sparseIndices.length; i++) {
          indicesPtr[i] = sparseIndices[i];
          valuesPtr[i] = sparseValues[i];
        }
        checkError(
          _b.zvec_sub_query_set_sparse_vector(
            _ptr,
            indicesPtr,
            valuesPtr,
            sparseIndices.length,
          ),
        );
      } finally {
        calloc.free(indicesPtr);
        calloc.free(valuesPtr);
      }
    }

    // Set FTS payload
    if (fts != null) {
      checkError(_b.zvec_sub_query_set_fts(_ptr, fts.nativePtr));
    }

    // Set query params
    if (queryParams != null) {
      _attachSubQueryParams(_ptr, queryParams);
    }
    if (ftsParams != null) {
      _attachFtsSubQueryParams(_ptr, ftsParams);
    }
  }

  final Pointer<zvec_sub_query_t> _ptr;

  /// The native pointer for internal use.
  Pointer<zvec_sub_query_t> get nativePtr => _ptr;

  /// Destroy the native sub-query.
  void destroy() {
    _b.zvec_sub_query_destroy(_ptr);
  }
}

void _attachSubQueryParams(
  Pointer<zvec_sub_query_t> queryPtr,
  QueryParams queryParams,
) {
  if (queryParams is HnswQueryParams) {
    final cloned = queryParams.cloneNativePtr();
    var transferred = false;
    try {
      checkError(_b.zvec_sub_query_set_hnsw_params(queryPtr, cloned));
      transferred = true;
    } finally {
      if (!transferred) queryParams.destroyNativePtr(cloned);
    }
  } else if (queryParams is IVFQueryParams) {
    final cloned = queryParams.cloneNativePtr();
    var transferred = false;
    try {
      checkError(_b.zvec_sub_query_set_ivf_params(queryPtr, cloned));
      transferred = true;
    } finally {
      if (!transferred) queryParams.destroyNativePtr(cloned);
    }
  } else if (queryParams is FlatQueryParams) {
    final cloned = queryParams.cloneNativePtr();
    var transferred = false;
    try {
      checkError(_b.zvec_sub_query_set_flat_params(queryPtr, cloned));
      transferred = true;
    } finally {
      if (!transferred) queryParams.destroyNativePtr(cloned);
    }
  } else {
    throw ArgumentError('Unsupported sub-query params: $queryParams');
  }
}

void _attachFtsSubQueryParams(
  Pointer<zvec_sub_query_t> queryPtr,
  FtsQueryParams queryParams,
) {
  final cloned = queryParams.cloneNativePtr();
  var transferred = false;
  try {
    checkError(_b.zvec_sub_query_set_fts_params(queryPtr, cloned));
    transferred = true;
  } finally {
    if (!transferred) queryParams.destroyNativePtr(cloned);
  }
}

/// A multi-query that combines multiple sub-queries with reranking.
///
/// Supports hybrid search combining dense vectors, sparse vectors, and FTS
/// results using RRF or weighted fusion.
///
/// Example:
/// ```dart
/// final query = MultiQuery(
///   subQueries: [
///     SubQuery(fieldName: 'embedding', vector: denseVector),
///     SubQuery(fieldName: 'content', fts: FtsQuery(matchString: 'database')),
///   ],
///   topk: 10,
///   rerank: RrfRerank(rankConstant: 60),
/// );
/// final results = collection.multiQuery(query);
/// ```
class MultiQuery {
  /// Create a multi-query.
  ///
  /// - [subQueries]: List of sub-queries to execute.
  /// - [topk]: Number of final results to return (default: 10).
  /// - [filter]: Optional filter expression.
  /// - [includeVector]: Whether to include vectors in results (default: false).
  /// - [outputFields]: Optional list of fields to include in results.
  /// - [rerank]: Rerank strategy for result fusion.
  MultiQuery({
    required List<SubQuery> subQueries,
    int topk = 10,
    String? filter,
    bool includeVector = false,
    List<String>? outputFields,
    RerankStrategy? rerank,
  }) : _ptr = _b.zvec_multi_query_create() {
    // Set topk
    checkError(_b.zvec_multi_query_set_topk(_ptr, topk));

    // Set filter
    if (filter != null) {
      final filterPtr = filter.toNativeUtf8().cast<Char>();
      try {
        checkError(_b.zvec_multi_query_set_filter(_ptr, filterPtr));
      } finally {
        calloc.free(filterPtr);
      }
    }

    // Set include vector
    checkError(_b.zvec_multi_query_set_include_vector(_ptr, includeVector));

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
          _b.zvec_multi_query_set_output_fields(
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

    // Set rerank strategy
    if (rerank != null) {
      if (rerank is RrfRerank) {
        checkError(
          _b.zvec_multi_query_set_rerank_rrf(_ptr, rerank.rankConstant),
        );
      } else if (rerank is WeightedRerank) {
        final weightsPtr = calloc<Double>(rerank.weights.length);
        try {
          for (var i = 0; i < rerank.weights.length; i++) {
            weightsPtr[i] = rerank.weights[i];
          }
          checkError(
            _b.zvec_multi_query_set_rerank_weighted(
              _ptr,
              weightsPtr,
              rerank.weights.length,
            ),
          );
        } finally {
          calloc.free(weightsPtr);
        }
      }
    }

    // Add sub-queries
    for (final sq in subQueries) {
      checkError(_b.zvec_multi_query_add_sub_query(_ptr, sq.nativePtr));
    }
  }

  final Pointer<zvec_multi_query_t> _ptr;

  /// The native pointer for internal use.
  Pointer<zvec_multi_query_t> get nativePtr => _ptr;

  /// Destroy the native multi-query.
  void destroy() {
    _b.zvec_multi_query_destroy(_ptr);
  }
}
