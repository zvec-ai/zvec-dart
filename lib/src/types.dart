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

/// Column/field data types — mirrors `zvec_data_type_t` constants in C API.
enum DataType {
  undefined(0),
  binary(1),
  string(2),
  bool_(3),
  int32(4),
  int64(5),
  uint32(6),
  uint64(7),
  float32(8),
  float64(9),
  vectorBinary32(20),
  vectorBinary64(21),
  vectorFp16(22),
  vectorFp32(23),
  vectorFp64(24),
  vectorInt4(25),
  vectorInt8(26),
  vectorInt16(27),
  sparseVectorFp16(30),
  sparseVectorFp32(31),
  arrayBinary(40),
  arrayString(41),
  arrayBool(42),
  arrayInt32(43),
  arrayInt64(44),
  arrayUint32(45),
  arrayUint64(46),
  arrayFloat(47),
  arrayDouble(48);

  const DataType(this.value);
  final int value;

  /// Whether this type represents a dense vector.
  bool get isDenseVector => value >= 20 && value <= 27;

  /// Whether this type represents a sparse vector.
  bool get isSparseVector => value >= 30 && value <= 31;

  /// Whether this type represents any vector (dense or sparse).
  bool get isVector => isDenseVector || isSparseVector;

  /// Whether this type represents an array.
  bool get isArray => value >= 40 && value <= 48;

  static DataType fromValue(int v) => DataType.values.firstWhere(
    (e) => e.value == v,
    orElse: () => DataType.undefined,
  );
}

/// Index algorithm types — mirrors `zvec_index_type_t` constants.
enum IndexType {
  undefined(0),
  hnsw(1),
  ivf(2),
  flat(3),
  hnswRabitq(4),
  invert(10),
  fts(11);

  const IndexType(this.value);
  final int value;

  static IndexType fromValue(int v) => IndexType.values.firstWhere(
    (e) => e.value == v,
    orElse: () => IndexType.undefined,
  );
}

/// Distance metric types — mirrors `zvec_metric_type_t` constants.
enum MetricType {
  undefined(0),
  l2(1),
  ip(2),
  cosine(3),
  mipsl2(4);

  const MetricType(this.value);
  final int value;

  static MetricType fromValue(int v) => MetricType.values.firstWhere(
    (e) => e.value == v,
    orElse: () => MetricType.undefined,
  );
}

/// Quantization types — mirrors `zvec_quantize_type_t` constants.
enum QuantizeType {
  undefined(0),
  fp16(1),
  int8(2),
  int4(3),
  rabitq(4);

  const QuantizeType(this.value);
  final int value;

  static QuantizeType fromValue(int v) => QuantizeType.values.firstWhere(
    (e) => e.value == v,
    orElse: () => QuantizeType.undefined,
  );
}

/// Log levels — mirrors `zvec_log_level_t`.
enum LogLevel {
  debug(0),
  info(1),
  warn(2),
  error(3),
  fatal(4);

  const LogLevel(this.value);
  final int value;

  static LogLevel fromValue(int v) => LogLevel.values.firstWhere(
    (e) => e.value == v,
    orElse: () => LogLevel.info,
  );
}

/// Log output types — mirrors `zvec_log_type_t`.
enum LogType {
  console(0),
  file(1);

  const LogType(this.value);
  final int value;

  static LogType fromValue(int v) => LogType.values.firstWhere(
    (e) => e.value == v,
    orElse: () => LogType.console,
  );
}
