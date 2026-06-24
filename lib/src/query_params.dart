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

/// Base class for query-time parameters.
abstract class QueryParams {
  /// The native pointer (type-erased) for passing to vector query.
  Pointer get nativePtr;

  /// Create a native copy for APIs that take ownership of query params.
  Pointer cloneNativePtr();

  /// Destroy a native copy created by [cloneNativePtr] if ownership was not
  /// transferred.
  void destroyNativePtr(Pointer ptr);
}

/// HNSW query parameters.
class HnswQueryParams extends QueryParams {
  /// Create HNSW query parameters.
  ///
  /// - [ef]: Exploration factor during search (default: 40).
  /// - [radius]: Search radius (default: 0.0).
  /// - [isLinear]: Whether to use linear search (default: false).
  /// - [isUsingRefiner]: Whether to use refiner (default: false).
  HnswQueryParams({
    int ef = 40,
    double radius = 0.0,
    bool isLinear = false,
    bool isUsingRefiner = false,
  }) : _ptr = _b.zvec_query_params_hnsw_create(
         ef,
         radius,
         isLinear,
         isUsingRefiner,
       );

  final Pointer<zvec_hnsw_query_params_t> _ptr;

  @override
  Pointer<zvec_hnsw_query_params_t> get nativePtr => _ptr;

  /// Get exploration factor.
  int get ef => _b.zvec_query_params_hnsw_get_ef(_ptr);

  /// Set exploration factor.
  set ef(int value) {
    checkError(_b.zvec_query_params_hnsw_set_ef(_ptr, value));
  }

  /// Get search radius.
  double get radius => _b.zvec_query_params_hnsw_get_radius(_ptr);

  /// Get whether linear search is enabled.
  bool get isLinear => _b.zvec_query_params_hnsw_get_is_linear(_ptr);

  /// Get whether refiner is enabled.
  bool get isUsingRefiner =>
      _b.zvec_query_params_hnsw_get_is_using_refiner(_ptr);

  @override
  Pointer<zvec_hnsw_query_params_t> cloneNativePtr() {
    return _b.zvec_query_params_hnsw_create(
      ef,
      radius,
      isLinear,
      isUsingRefiner,
    );
  }

  @override
  void destroyNativePtr(Pointer ptr) {
    _b.zvec_query_params_hnsw_destroy(ptr.cast<zvec_hnsw_query_params_t>());
  }

  /// Destroy the native query params.
  void destroy() {
    _b.zvec_query_params_hnsw_destroy(_ptr);
  }
}

/// IVF query parameters.
class IVFQueryParams extends QueryParams {
  /// Create IVF query parameters.
  ///
  /// - [nprobe]: Number of clusters to probe (default: 10).
  /// - [isUsingRefiner]: Whether to use refiner (default: false).
  /// - [scaleFactor]: Scale factor (default: 10.0).
  IVFQueryParams({
    int nprobe = 10,
    bool isUsingRefiner = false,
    double scaleFactor = 10.0,
  }) : _ptr = _b.zvec_query_params_ivf_create(
         nprobe,
         isUsingRefiner,
         scaleFactor,
       );

  final Pointer<zvec_ivf_query_params_t> _ptr;

  @override
  Pointer<zvec_ivf_query_params_t> get nativePtr => _ptr;

  /// Get number of probe clusters.
  int get nprobe => _b.zvec_query_params_ivf_get_nprobe(_ptr);

  /// Set number of probe clusters.
  set nprobe(int value) {
    checkError(_b.zvec_query_params_ivf_set_nprobe(_ptr, value));
  }

  /// Get scale factor.
  double get scaleFactor => _b.zvec_query_params_ivf_get_scale_factor(_ptr);

  /// Get search radius.
  double get radius => _b.zvec_query_params_ivf_get_radius(_ptr);

  /// Get whether linear search is enabled.
  bool get isLinear => _b.zvec_query_params_ivf_get_is_linear(_ptr);

  /// Get whether refiner is enabled.
  bool get isUsingRefiner =>
      _b.zvec_query_params_ivf_get_is_using_refiner(_ptr);

  @override
  Pointer<zvec_ivf_query_params_t> cloneNativePtr() {
    final ptr = _b.zvec_query_params_ivf_create(
      nprobe,
      isUsingRefiner,
      scaleFactor,
    );
    try {
      checkError(_b.zvec_query_params_ivf_set_radius(ptr, radius));
      checkError(_b.zvec_query_params_ivf_set_is_linear(ptr, isLinear));
      return ptr;
    } catch (_) {
      _b.zvec_query_params_ivf_destroy(ptr);
      rethrow;
    }
  }

  @override
  void destroyNativePtr(Pointer ptr) {
    _b.zvec_query_params_ivf_destroy(ptr.cast<zvec_ivf_query_params_t>());
  }

  /// Destroy the native query params.
  void destroy() {
    _b.zvec_query_params_ivf_destroy(_ptr);
  }
}

/// Flat query parameters.
class FlatQueryParams extends QueryParams {
  /// Create Flat query parameters.
  ///
  /// - [isUsingRefiner]: Whether to use refiner (default: false).
  /// - [scaleFactor]: Scale factor (default: 10.0).
  FlatQueryParams({bool isUsingRefiner = false, double scaleFactor = 10.0})
    : _ptr = _b.zvec_query_params_flat_create(isUsingRefiner, scaleFactor);

  final Pointer<zvec_flat_query_params_t> _ptr;

  @override
  Pointer<zvec_flat_query_params_t> get nativePtr => _ptr;

  /// Get scale factor.
  double get scaleFactor => _b.zvec_query_params_flat_get_scale_factor(_ptr);

  /// Get search radius.
  double get radius => _b.zvec_query_params_flat_get_radius(_ptr);

  /// Get whether linear search is enabled.
  bool get isLinear => _b.zvec_query_params_flat_get_is_linear(_ptr);

  /// Get whether refiner is enabled.
  bool get isUsingRefiner =>
      _b.zvec_query_params_flat_get_is_using_refiner(_ptr);

  @override
  Pointer<zvec_flat_query_params_t> cloneNativePtr() {
    final ptr = _b.zvec_query_params_flat_create(isUsingRefiner, scaleFactor);
    try {
      checkError(_b.zvec_query_params_flat_set_radius(ptr, radius));
      checkError(_b.zvec_query_params_flat_set_is_linear(ptr, isLinear));
      return ptr;
    } catch (_) {
      _b.zvec_query_params_flat_destroy(ptr);
      rethrow;
    }
  }

  @override
  void destroyNativePtr(Pointer ptr) {
    _b.zvec_query_params_flat_destroy(ptr.cast<zvec_flat_query_params_t>());
  }

  /// Destroy the native query params.
  void destroy() {
    _b.zvec_query_params_flat_destroy(_ptr);
  }
}

/// FTS query parameters.
class FtsQueryParams extends QueryParams {
  /// Create FTS query parameters.
  ///
  /// - [defaultOperator]: Default boolean operator ('AND' or 'OR', default: 'OR').
  FtsQueryParams({String defaultOperator = 'OR'})
    : _ptr = _createFts(defaultOperator);

  static Pointer<zvec_fts_query_params_t> _createFts(String op) {
    final opPtr = op.toNativeUtf8().cast<Char>();
    try {
      return _b.zvec_query_params_fts_create(opPtr);
    } finally {
      calloc.free(opPtr);
    }
  }

  final Pointer<zvec_fts_query_params_t> _ptr;

  @override
  Pointer<zvec_fts_query_params_t> get nativePtr => _ptr;

  /// Get the default operator.
  String get defaultOperator {
    final ptr = _b.zvec_query_params_fts_get_default_operator(_ptr);
    return ptr.cast<Utf8>().toDartString();
  }

  /// Set the default operator.
  set defaultOperator(String value) {
    final opPtr = value.toNativeUtf8().cast<Char>();
    try {
      checkError(_b.zvec_query_params_fts_set_default_operator(_ptr, opPtr));
    } finally {
      calloc.free(opPtr);
    }
  }

  @override
  Pointer<zvec_fts_query_params_t> cloneNativePtr() {
    return _createFts(defaultOperator);
  }

  @override
  void destroyNativePtr(Pointer ptr) {
    _b.zvec_query_params_fts_destroy(ptr.cast<zvec_fts_query_params_t>());
  }

  /// Destroy the native query params.
  void destroy() {
    _b.zvec_query_params_fts_destroy(_ptr);
  }
}
