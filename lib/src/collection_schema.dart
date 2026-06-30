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
import 'index_params.dart';
import 'types.dart';
import 'zvec_bindings.dart';
import 'zvec_library.dart';

ZvecBindings get _b => ZvecLibrary.bindings;

/// Schema definition for a single field in a collection.
class FieldSchema {
  /// Create a field schema.
  ///
  /// - [name]: Field name.
  /// - [dataType]: The data type of the field.
  /// - [nullable]: Whether the field can be null (default: true).
  /// - [dimension]: Vector dimension (required for vector fields, 0 for scalars).
  FieldSchema({
    required String name,
    required DataType dataType,
    bool nullable = true,
    int dimension = 0,
  }) : _ownsPtr = true {
    final namePtr = name.toNativeUtf8().cast<Char>();
    try {
      _ptr = _b.zvec_field_schema_create(
        namePtr,
        dataType.value,
        nullable,
        dimension,
      );
    } finally {
      calloc.free(namePtr);
    }
  }

  /// Wrap an existing native pointer (non-owning).
  FieldSchema._fromPtr(this._ptr) : _ownsPtr = false;

  late final Pointer<zvec_field_schema_t> _ptr;
  final bool _ownsPtr;

  /// The native pointer for internal use.
  Pointer<zvec_field_schema_t> get nativePtr => _ptr;

  /// Get the field name.
  String get name {
    final ptr = _b.zvec_field_schema_get_name(_ptr);
    return ptr.cast<Utf8>().toDartString();
  }

  /// Get the data type.
  DataType get dataType =>
      DataType.fromValue(_b.zvec_field_schema_get_data_type(_ptr));

  /// Whether the field is nullable.
  bool get isNullable => _b.zvec_field_schema_is_nullable(_ptr);

  /// Get the vector dimension (0 for non-vector fields).
  int get dimension => _b.zvec_field_schema_get_dimension(_ptr);

  /// Whether this is a vector field (dense or sparse).
  bool get isVectorField => _b.zvec_field_schema_is_vector_field(_ptr);

  /// Whether this is a dense vector field.
  bool get isDenseVector => _b.zvec_field_schema_is_dense_vector(_ptr);

  /// Whether this is a sparse vector field.
  bool get isSparseVector => _b.zvec_field_schema_is_sparse_vector(_ptr);

  /// Whether this field has an index.
  bool get hasIndex => _b.zvec_field_schema_has_index(_ptr);

  /// Get the index type.
  IndexType get indexType =>
      IndexType.fromValue(_b.zvec_field_schema_get_index_type(_ptr));

  /// Set index parameters for this field.
  void setIndexParams(IndexParams params) {
    checkError(_b.zvec_field_schema_set_index_params(_ptr, params.nativePtr));
  }

  /// Destroy the native field schema. Only call if this object owns the pointer.
  void destroy() {
    if (_ownsPtr) {
      _b.zvec_field_schema_destroy(_ptr);
    }
  }
}

/// Convenience class for creating vector field schemas.
///
/// Equivalent to [FieldSchema] with a vector data type pre-configured.
class VectorSchema extends FieldSchema {
  /// Create a vector field schema.
  ///
  /// - [name]: Field name.
  /// - [dataType]: Vector data type (default: [DataType.vectorFp32]).
  /// - [dimension]: Vector dimension.
  /// - [indexParams]: Optional index parameters.
  VectorSchema(
    String name,
    int dimension, {
    super.dataType = DataType.vectorFp32,
    IndexParams? indexParams,
  }) : super(name: name, nullable: false, dimension: dimension) {
    if (indexParams != null) {
      setIndexParams(indexParams);
    }
  }
}

/// Schema definition for a collection, containing one or more fields.
class CollectionSchema {
  /// Create a collection schema.
  ///
  /// - [name]: Collection name.
  /// - [fields]: List of field schemas to add.
  CollectionSchema({required String name, List<FieldSchema>? fields})
    : _ownsPtr = true {
    final namePtr = name.toNativeUtf8().cast<Char>();
    try {
      _ptr = _b.zvec_collection_schema_create(namePtr);
    } finally {
      calloc.free(namePtr);
    }
    if (fields != null) {
      for (final field in fields) {
        addField(field);
      }
    }
  }

  /// Wrap an existing native pointer.
  CollectionSchema._fromPtr(this._ptr, {bool ownsPtr = true})
    : _ownsPtr = ownsPtr;

  /// Create from a native pointer (owning). Used internally by Collection.
  factory CollectionSchema.fromNativePtr(
    Pointer<zvec_collection_schema_t> ptr,
  ) => CollectionSchema._fromPtr(ptr, ownsPtr: true);

  late final Pointer<zvec_collection_schema_t> _ptr;
  final bool _ownsPtr;

  /// The native pointer for internal use.
  Pointer<zvec_collection_schema_t> get nativePtr => _ptr;

  /// Get the collection name.
  String get name {
    final ptr = _b.zvec_collection_schema_get_name(_ptr);
    return ptr.cast<Utf8>().toDartString();
  }

  /// Set the collection name.
  set name(String value) {
    final namePtr = value.toNativeUtf8().cast<Char>();
    try {
      checkError(_b.zvec_collection_schema_set_name(_ptr, namePtr));
    } finally {
      calloc.free(namePtr);
    }
  }

  /// Add a field to the schema. The field is cloned internally.
  void addField(FieldSchema field) {
    checkError(_b.zvec_collection_schema_add_field(_ptr, field.nativePtr));
  }

  /// Check if a field exists by name.
  bool hasField(String fieldName) {
    final namePtr = fieldName.toNativeUtf8().cast<Char>();
    try {
      return _b.zvec_collection_schema_has_field(_ptr, namePtr);
    } finally {
      calloc.free(namePtr);
    }
  }

  /// Get a field by name. Returns null if not found.
  ///
  /// The returned [FieldSchema] does NOT own the native pointer;
  /// do not call destroy on it.
  FieldSchema? getField(String fieldName) {
    final namePtr = fieldName.toNativeUtf8().cast<Char>();
    try {
      final fieldPtr = _b.zvec_collection_schema_get_field(_ptr, namePtr);
      if (fieldPtr == nullptr) return null;
      return FieldSchema._fromPtr(fieldPtr);
    } finally {
      calloc.free(namePtr);
    }
  }

  /// Drop a field from the schema.
  void dropField(String fieldName) {
    final namePtr = fieldName.toNativeUtf8().cast<Char>();
    try {
      checkError(_b.zvec_collection_schema_drop_field(_ptr, namePtr));
    } finally {
      calloc.free(namePtr);
    }
  }

  /// Add an index to a field.
  void addIndex(String fieldName, IndexParams params) {
    final namePtr = fieldName.toNativeUtf8().cast<Char>();
    try {
      checkError(
        _b.zvec_collection_schema_add_index(_ptr, namePtr, params.nativePtr),
      );
    } finally {
      calloc.free(namePtr);
    }
  }

  /// Drop an index from a field.
  void dropIndex(String fieldName) {
    final namePtr = fieldName.toNativeUtf8().cast<Char>();
    try {
      checkError(_b.zvec_collection_schema_drop_index(_ptr, namePtr));
    } finally {
      calloc.free(namePtr);
    }
  }

  /// Validate the schema.
  ///
  /// Throws [ZvecException] if the schema is invalid.
  void validate() {
    final errorMsgPtr = calloc<Pointer<zvec_string_t>>();
    try {
      checkError(_b.zvec_collection_schema_validate(_ptr, errorMsgPtr));
    } finally {
      if (errorMsgPtr.value != nullptr) {
        _b.zvec_free_string(errorMsgPtr.value);
      }
      calloc.free(errorMsgPtr);
    }
  }

  /// Destroy the native collection schema.
  void destroy() {
    if (_ownsPtr) {
      _b.zvec_collection_schema_destroy(_ptr);
    }
  }
}
