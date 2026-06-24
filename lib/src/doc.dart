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
import 'types.dart';
import 'zvec_bindings.dart';
import 'zvec_library.dart';

ZvecBindings get _b => ZvecLibrary.bindings;

/// A document in a Zvec collection.
///
/// Documents contain scalar fields and vector embeddings. Each document
/// has a primary key (pk) that uniquely identifies it.
///
/// Example:
/// ```dart
/// final doc = Doc(id: 'doc_1')
///   ..setField('title', 'Hello World')
///   ..setVector('embedding', Float32List.fromList([0.1, 0.2, 0.3, 0.4]));
/// ```
class Doc {
  static final Finalizer<Pointer<zvec_doc_t>> _finalizer =
      Finalizer<Pointer<zvec_doc_t>>((ptr) => _b.zvec_doc_destroy(ptr));

  /// Create a new empty document.
  ///
  /// - [id]: Optional primary key. If not set, one will be auto-generated.
  /// - [fields]: Optional map of field name to value. Values are auto-typed:
  ///   - [String] -> STRING
  ///   - [int] -> INT64
  ///   - [double] -> DOUBLE
  ///   - [bool] -> BOOL
  ///   - [Float32List] -> VECTOR_FP32
  ///   - [Float64List] -> VECTOR_FP64
  Doc({String? id, Map<String, dynamic>? fields})
    : _ptr = _b.zvec_doc_create(),
      _ownsPtr = true {
    _attachFinalizer();
    if (id != null) {
      pk = id;
    }
    if (fields != null) {
      fields.forEach((key, value) {
        if (value is Float32List) {
          setVector(key, value);
        } else if (value is Float64List) {
          setVector64(key, value);
        } else {
          setField(key, value);
        }
      });
    }
  }

  /// Wrap an existing native doc pointer.
  Doc._fromPtr(this._ptr, {bool ownsPtr = false}) : _ownsPtr = ownsPtr {
    _attachFinalizer();
  }

  /// Create from a native pointer (non-owning). Used internally by Collection.
  factory Doc.fromNativePtr(Pointer<zvec_doc_t> ptr) => Doc._fromPtr(ptr);

  /// Create from a native pointer and take ownership of it.
  factory Doc.fromOwnedNativePtr(Pointer<zvec_doc_t> ptr) =>
      Doc._fromPtr(ptr, ownsPtr: true);

  final Pointer<zvec_doc_t> _ptr;
  final bool _ownsPtr;
  bool _destroyed = false;

  /// The native pointer for internal use.
  Pointer<zvec_doc_t> get nativePtr => _ptr;

  void _attachFinalizer() {
    if (_ownsPtr && _ptr != nullptr) {
      _finalizer.attach(this, _ptr, detach: this);
    }
  }

  // ---------------------------------------------------------------------------
  // Primary key
  // ---------------------------------------------------------------------------

  /// Get the primary key.
  String? get pk {
    final ptr = _b.zvec_doc_get_pk_pointer(_ptr);
    if (ptr == nullptr) return null;
    return ptr.cast<Utf8>().toDartString();
  }

  /// Set the primary key.
  set pk(String? value) {
    if (value == null) return;
    final pkPtr = value.toNativeUtf8().cast<Char>();
    try {
      _b.zvec_doc_set_pk(_ptr, pkPtr);
    } finally {
      calloc.free(pkPtr);
    }
  }

  /// Get the internal document ID.
  int get docId => _b.zvec_doc_get_doc_id(_ptr);

  /// Get the document score (set after query operations).
  double get score => _b.zvec_doc_get_score(_ptr);

  /// Get the number of fields in this document.
  int get fieldCount => _b.zvec_doc_get_field_count(_ptr);

  /// Whether the document has no fields.
  bool get isEmpty => _b.zvec_doc_is_empty(_ptr);

  /// Check if a field exists.
  bool hasField(String name) {
    final namePtr = name.toNativeUtf8().cast<Char>();
    try {
      return _b.zvec_doc_has_field(_ptr, namePtr);
    } finally {
      calloc.free(namePtr);
    }
  }

  /// Check if a field is null.
  bool isFieldNull(String name) {
    final namePtr = name.toNativeUtf8().cast<Char>();
    try {
      return _b.zvec_doc_is_field_null(_ptr, namePtr);
    } finally {
      calloc.free(namePtr);
    }
  }

  // ---------------------------------------------------------------------------
  // Field setters
  // ---------------------------------------------------------------------------

  /// Set a scalar field value. Supported types:
  /// - [String] -> STRING
  /// - [int] -> INT64
  /// - [double] -> DOUBLE
  /// - [bool] -> BOOL
  void setField(String name, dynamic value) {
    if (value is String) {
      _setStringField(name, value);
    } else if (value is int) {
      _setInt64Field(name, value);
    } else if (value is double) {
      _setDoubleField(name, value);
    } else if (value is bool) {
      _setBoolField(name, value);
    } else {
      throw ArgumentError('Unsupported field value type: ${value.runtimeType}');
    }
  }

  /// Set a FP32 vector field.
  void setVector(String name, Float32List vector) {
    final namePtr = name.toNativeUtf8().cast<Char>();
    final dataPtr = calloc<Float>(vector.length);
    try {
      for (var i = 0; i < vector.length; i++) {
        dataPtr[i] = vector[i];
      }
      checkError(
        _b.zvec_doc_add_field_by_value(
          _ptr,
          namePtr,
          DataType.vectorFp32.value,
          dataPtr.cast(),
          vector.length * sizeOf<Float>(),
        ),
      );
    } finally {
      calloc.free(namePtr);
      calloc.free(dataPtr);
    }
  }

  /// Set a FP64 vector field.
  void setVector64(String name, Float64List vector) {
    final namePtr = name.toNativeUtf8().cast<Char>();
    final dataPtr = calloc<Double>(vector.length);
    try {
      for (var i = 0; i < vector.length; i++) {
        dataPtr[i] = vector[i];
      }
      checkError(
        _b.zvec_doc_add_field_by_value(
          _ptr,
          namePtr,
          DataType.vectorFp64.value,
          dataPtr.cast(),
          vector.length * sizeOf<Double>(),
        ),
      );
    } finally {
      calloc.free(namePtr);
      calloc.free(dataPtr);
    }
  }

  /// Mark a field as null.
  void setFieldNull(String name) {
    final namePtr = name.toNativeUtf8().cast<Char>();
    try {
      checkError(_b.zvec_doc_set_field_null(_ptr, namePtr));
    } finally {
      calloc.free(namePtr);
    }
  }

  void _setStringField(String name, String value) {
    final namePtr = name.toNativeUtf8().cast<Char>();
    final valuePtr = value.toNativeUtf8();
    try {
      checkError(
        _b.zvec_doc_add_field_by_value(
          _ptr,
          namePtr,
          DataType.string.value,
          valuePtr.cast(),
          valuePtr.length,
        ),
      );
    } finally {
      calloc.free(namePtr);
      calloc.free(valuePtr);
    }
  }

  void _setInt64Field(String name, int value) {
    final namePtr = name.toNativeUtf8().cast<Char>();
    final valuePtr = calloc<Int64>();
    try {
      valuePtr.value = value;
      checkError(
        _b.zvec_doc_add_field_by_value(
          _ptr,
          namePtr,
          DataType.int64.value,
          valuePtr.cast(),
          sizeOf<Int64>(),
        ),
      );
    } finally {
      calloc.free(namePtr);
      calloc.free(valuePtr);
    }
  }

  void _setDoubleField(String name, double value) {
    final namePtr = name.toNativeUtf8().cast<Char>();
    final valuePtr = calloc<Double>();
    try {
      valuePtr.value = value;
      checkError(
        _b.zvec_doc_add_field_by_value(
          _ptr,
          namePtr,
          DataType.float64.value,
          valuePtr.cast(),
          sizeOf<Double>(),
        ),
      );
    } finally {
      calloc.free(namePtr);
      calloc.free(valuePtr);
    }
  }

  void _setBoolField(String name, bool value) {
    final namePtr = name.toNativeUtf8().cast<Char>();
    final valuePtr = calloc<Bool>();
    try {
      valuePtr.value = value;
      checkError(
        _b.zvec_doc_add_field_by_value(
          _ptr,
          namePtr,
          DataType.bool_.value,
          valuePtr.cast(),
          sizeOf<Bool>(),
        ),
      );
    } finally {
      calloc.free(namePtr);
      calloc.free(valuePtr);
    }
  }

  // ---------------------------------------------------------------------------
  // Field getters
  // ---------------------------------------------------------------------------

  /// Get a string field value.
  String? getString(String name) {
    if (!hasField(name) || isFieldNull(name)) return null;
    final namePtr = name.toNativeUtf8().cast<Char>();
    final valuePtr = calloc<Pointer<Void>>();
    final sizePtr = calloc<Size>();
    try {
      final rc = _b.zvec_doc_get_field_value_pointer(
        _ptr,
        namePtr,
        DataType.string.value,
        valuePtr,
        sizePtr,
      );
      if (rc != zvec_error_code_t.ZVEC_OK) return null;
      if (valuePtr.value == nullptr) return null;
      return valuePtr.value.cast<Utf8>().toDartString(length: sizePtr.value);
    } finally {
      calloc.free(namePtr);
      calloc.free(valuePtr);
      calloc.free(sizePtr);
    }
  }

  /// Get an int64 field value.
  int? getInt64(String name) {
    if (!hasField(name) || isFieldNull(name)) return null;
    final namePtr = name.toNativeUtf8().cast<Char>();
    final valuePtr = calloc<Int64>();
    try {
      final rc = _b.zvec_doc_get_field_value_basic(
        _ptr,
        namePtr,
        DataType.int64.value,
        valuePtr.cast(),
        sizeOf<Int64>(),
      );
      if (rc != zvec_error_code_t.ZVEC_OK) return null;
      return valuePtr.value;
    } finally {
      calloc.free(namePtr);
      calloc.free(valuePtr);
    }
  }

  /// Get a double field value.
  double? getDouble(String name) {
    if (!hasField(name) || isFieldNull(name)) return null;
    final namePtr = name.toNativeUtf8().cast<Char>();
    final valuePtr = calloc<Double>();
    try {
      final rc = _b.zvec_doc_get_field_value_basic(
        _ptr,
        namePtr,
        DataType.float64.value,
        valuePtr.cast(),
        sizeOf<Double>(),
      );
      if (rc != zvec_error_code_t.ZVEC_OK) return null;
      return valuePtr.value;
    } finally {
      calloc.free(namePtr);
      calloc.free(valuePtr);
    }
  }

  /// Get a float field value.
  double? getFloat(String name) {
    if (!hasField(name) || isFieldNull(name)) return null;
    final namePtr = name.toNativeUtf8().cast<Char>();
    final valuePtr = calloc<Float>();
    try {
      final rc = _b.zvec_doc_get_field_value_basic(
        _ptr,
        namePtr,
        DataType.float32.value,
        valuePtr.cast(),
        sizeOf<Float>(),
      );
      if (rc != zvec_error_code_t.ZVEC_OK) return null;
      return valuePtr.value;
    } finally {
      calloc.free(namePtr);
      calloc.free(valuePtr);
    }
  }

  /// Get a bool field value.
  bool? getBool(String name) {
    if (!hasField(name) || isFieldNull(name)) return null;
    final namePtr = name.toNativeUtf8().cast<Char>();
    final valuePtr = calloc<Bool>();
    try {
      final rc = _b.zvec_doc_get_field_value_basic(
        _ptr,
        namePtr,
        DataType.bool_.value,
        valuePtr.cast(),
        sizeOf<Bool>(),
      );
      if (rc != zvec_error_code_t.ZVEC_OK) return null;
      return valuePtr.value;
    } finally {
      calloc.free(namePtr);
      calloc.free(valuePtr);
    }
  }

  /// Get a FP32 vector field value.
  Float32List? getVector(String name) {
    if (!hasField(name) || isFieldNull(name)) return null;
    final namePtr = name.toNativeUtf8().cast<Char>();
    final valuePtr = calloc<Pointer<Void>>();
    final sizePtr = calloc<Size>();
    try {
      final rc = _b.zvec_doc_get_field_value_pointer(
        _ptr,
        namePtr,
        DataType.vectorFp32.value,
        valuePtr,
        sizePtr,
      );
      if (rc != zvec_error_code_t.ZVEC_OK) return null;
      if (valuePtr.value == nullptr) return null;
      final length = sizePtr.value ~/ sizeOf<Float>();
      final floatPtr = valuePtr.value.cast<Float>();
      final result = Float32List(length);
      for (var i = 0; i < length; i++) {
        result[i] = floatPtr[i];
      }
      return result;
    } finally {
      calloc.free(namePtr);
      calloc.free(valuePtr);
      calloc.free(sizePtr);
    }
  }

  /// Get all field names.
  List<String> get fieldNames {
    final namesPtr = calloc<Pointer<Pointer<Char>>>();
    final countPtr = calloc<Size>();
    try {
      final rc = _b.zvec_doc_get_field_names(_ptr, namesPtr, countPtr);
      if (rc != zvec_error_code_t.ZVEC_OK) return [];
      final count = countPtr.value;
      final names = <String>[];
      for (var i = 0; i < count; i++) {
        names.add(namesPtr.value[i].cast<Utf8>().toDartString());
      }
      if (namesPtr.value != nullptr) {
        _b.zvec_free_str_array(namesPtr.value, count);
      }
      return names;
    } finally {
      calloc.free(namesPtr);
      calloc.free(countPtr);
    }
  }

  /// Destroy the native document. Only call if this object owns the pointer.
  void destroy() {
    if (_ownsPtr && !_destroyed) {
      _finalizer.detach(this);
      _b.zvec_doc_destroy(_ptr);
      _destroyed = true;
    }
  }

  @override
  String toString() {
    final p = pk ?? '(none)';
    return 'Doc(pk=$p, fields=$fieldCount, score=$score)';
  }
}
