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

/// Dart SDK for Zvec — a lightweight, lightning-fast, in-process vector
/// database by Alibaba.
///
/// ```dart
/// import 'package:zvec/zvec.dart';
///
/// void main() {
///   Zvec.initialize();
///
///   final schema = CollectionSchema(name: 'demo', fields: [
///     VectorSchema('embedding', 4, indexParams: HnswIndexParams()),
///     FieldSchema(name: 'title', dataType: DataType.string),
///   ]);
///
///   final collection = Collection.createAndOpen('/tmp/demo', schema);
///   // ... insert, query, fetch ...
///   collection.close();
///
///   Zvec.shutdown();
/// }
/// ```
library zvec;

export 'src/collection.dart';
export 'src/collection_options.dart';
export 'src/collection_schema.dart';
export 'src/collection_stats.dart';
export 'src/config.dart';
export 'src/doc.dart';
export 'src/errors.dart';
export 'src/fts_query.dart';
export 'src/index_params.dart';
export 'src/multi_query.dart';
export 'src/query_params.dart';
export 'src/types.dart';
export 'src/vector_query.dart';
