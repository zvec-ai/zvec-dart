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

ZvecBindings get _b => ZvecLibrary.bindings;

/// Base class for index parameters.
///
/// Use concrete subclasses [HnswIndexParams], [IVFIndexParams],
/// [FlatIndexParams], or [InvertIndexParams].
abstract class IndexParams {
  IndexParams._(this._ptr);

  final Pointer<zvec_index_params_t> _ptr;

  /// The native pointer for internal use.
  Pointer<zvec_index_params_t> get nativePtr => _ptr;

  /// The index type.
  IndexType get indexType =>
      IndexType.fromValue(_b.zvec_index_params_get_type(_ptr));

  /// The distance metric type (for vector indexes).
  MetricType get metricType =>
      MetricType.fromValue(_b.zvec_index_params_get_metric_type(_ptr));

  /// The quantization type (for vector indexes).
  QuantizeType get quantizeType =>
      QuantizeType.fromValue(_b.zvec_index_params_get_quantize_type(_ptr));

  /// Destroy the native index params. Call when no longer needed and
  /// ownership has not been transferred.
  void destroy() {
    _b.zvec_index_params_destroy(_ptr);
  }
}

/// HNSW index parameters.
class HnswIndexParams extends IndexParams {
  /// Create HNSW index parameters.
  ///
  /// - [m]: Graph connectivity parameter (default: 16)
  /// - [efConstruction]: Construction exploration factor (default: 200)
  /// - [metricType]: Distance metric (default: cosine)
  /// - [quantizeType]: Quantization type (default: undefined/none)
  HnswIndexParams({
    int m = 16,
    int efConstruction = 200,
    MetricType metricType = MetricType.cosine,
    QuantizeType quantizeType = QuantizeType.undefined,
  }) : super._(_createHnsw(m, efConstruction, metricType, quantizeType));

  static Pointer<zvec_index_params_t> _createHnsw(
    int m,
    int efConstruction,
    MetricType metric,
    QuantizeType quant,
  ) {
    final ptr = _b.zvec_index_params_create(IndexType.hnsw.value);
    checkError(_b.zvec_index_params_set_metric_type(ptr, metric.value));
    checkError(_b.zvec_index_params_set_quantize_type(ptr, quant.value));
    checkError(_b.zvec_index_params_set_hnsw_params(ptr, m, efConstruction));
    return ptr;
  }

  /// Get the M (connectivity) parameter.
  int get m => _b.zvec_index_params_get_hnsw_m(_ptr);

  /// Get the ef_construction parameter.
  int get efConstruction => _b.zvec_index_params_get_hnsw_ef_construction(_ptr);
}

/// IVF index parameters.
class IVFIndexParams extends IndexParams {
  /// Create IVF index parameters.
  ///
  /// - [nList]: Number of cluster centers (default: 100)
  /// - [nIters]: Number of iterations (default: 10)
  /// - [useSoar]: Whether to use SOAR algorithm (default: false)
  /// - [metricType]: Distance metric (default: cosine)
  /// - [quantizeType]: Quantization type (default: undefined/none)
  IVFIndexParams({
    int nList = 100,
    int nIters = 10,
    bool useSoar = false,
    MetricType metricType = MetricType.cosine,
    QuantizeType quantizeType = QuantizeType.undefined,
  }) : super._(_createIVF(nList, nIters, useSoar, metricType, quantizeType));

  static Pointer<zvec_index_params_t> _createIVF(
    int nList,
    int nIters,
    bool useSoar,
    MetricType metric,
    QuantizeType quant,
  ) {
    final ptr = _b.zvec_index_params_create(IndexType.ivf.value);
    checkError(_b.zvec_index_params_set_metric_type(ptr, metric.value));
    checkError(_b.zvec_index_params_set_quantize_type(ptr, quant.value));
    checkError(
      _b.zvec_index_params_set_ivf_params(ptr, nList, nIters, useSoar),
    );
    return ptr;
  }
}

/// Flat (brute-force) index parameters.
class FlatIndexParams extends IndexParams {
  /// Create Flat index parameters.
  ///
  /// - [metricType]: Distance metric (default: cosine)
  /// - [quantizeType]: Quantization type (default: undefined/none)
  FlatIndexParams({
    MetricType metricType = MetricType.cosine,
    QuantizeType quantizeType = QuantizeType.undefined,
  }) : super._(_createFlat(metricType, quantizeType));

  static Pointer<zvec_index_params_t> _createFlat(
    MetricType metric,
    QuantizeType quant,
  ) {
    final ptr = _b.zvec_index_params_create(IndexType.flat.value);
    checkError(_b.zvec_index_params_set_metric_type(ptr, metric.value));
    checkError(_b.zvec_index_params_set_quantize_type(ptr, quant.value));
    return ptr;
  }
}

/// Inverted index parameters (for scalar fields).
class InvertIndexParams extends IndexParams {
  /// Create inverted index parameters.
  ///
  /// - [enableRangeOpt]: Whether to enable range optimization (default: false)
  /// - [enableWildcard]: Whether to enable extended wildcard (default: false)
  InvertIndexParams({bool enableRangeOpt = false, bool enableWildcard = false})
    : super._(_createInvert(enableRangeOpt, enableWildcard));

  static Pointer<zvec_index_params_t> _createInvert(
    bool enableRangeOpt,
    bool enableWildcard,
  ) {
    final ptr = _b.zvec_index_params_create(IndexType.invert.value);
    checkError(
      _b.zvec_index_params_set_invert_params(
        ptr,
        enableRangeOpt,
        enableWildcard,
      ),
    );
    return ptr;
  }
}

/// FTS (Full-Text Search) index parameters.
class FtsIndexParams extends IndexParams {
  /// Create FTS index parameters.
  ///
  /// - [tokenizerName]: Name of the tokenizer (e.g. 'jieba', 'standard').
  /// - [filters]: Optional list of text filters to apply.
  /// - [extraParams]: Optional extra parameters as JSON string.
  FtsIndexParams({
    required String tokenizerName,
    List<String>? filters,
    String? extraParams,
  }) : super._(_createFts(tokenizerName, filters, extraParams));

  static Pointer<zvec_index_params_t> _createFts(
    String tokenizerName,
    List<String>? filters,
    String? extraParams,
  ) {
    final ptr = _b.zvec_index_params_create(IndexType.fts.value);
    final tokPtr = tokenizerName.toNativeUtf8().cast<Char>();
    Pointer<zvec_string_array_t> filtersPtr = nullptr.cast();
    final extraPtr =
        extraParams?.toNativeUtf8().cast<Char>() ?? nullptr.cast<Char>();
    try {
      // Create string array for filters if provided
      if (filters != null && filters.isNotEmpty) {
        filtersPtr = _b.zvec_string_array_create(filters.length);
        for (var i = 0; i < filters.length; i++) {
          final fPtr = filters[i].toNativeUtf8().cast<Char>();
          _b.zvec_string_array_add(filtersPtr, i, fPtr);
          calloc.free(fPtr);
        }
      }
      checkError(
        _b.zvec_index_params_set_fts_params(ptr, tokPtr, filtersPtr, extraPtr),
      );
      return ptr;
    } finally {
      calloc.free(tokPtr);
      if (extraParams != null) calloc.free(extraPtr);
      if (filtersPtr != nullptr.cast()) {
        _b.zvec_string_array_destroy(filtersPtr);
      }
    }
  }
}
