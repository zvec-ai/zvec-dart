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

// FFI-dependent unit tests for the Zvec Dart SDK.
//
// These tests require the native library (libzvec.dylib on macOS).
// Run with:
//   bash scripts/run_tests.sh test/zvec_native_test.dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zvec/zvec.dart';

/// Create a fresh temp directory for test isolation.
Directory _createTempDir(String prefix) {
  return Directory.systemTemp.createTempSync('zvec_test_$prefix');
}

/// Return a sub-path inside [dir] that does NOT yet exist.
/// Collection.createAndOpen requires the target path to be absent.
String _dbPath(Directory dir) => '${dir.path}/db';

/// Clean up a temp directory.
void _cleanupDir(Directory dir) {
  if (dir.existsSync()) {
    dir.deleteSync(recursive: true);
  }
}

/// Helper: create a minimal schema with a 4-dim FP32 vector and a string field.
CollectionSchema _createTestSchema() {
  return CollectionSchema(
    name: 'test_collection',
    fields: [
      VectorSchema('embedding', 4, indexParams: HnswIndexParams()),
      FieldSchema(name: 'title', dataType: DataType.string),
      FieldSchema(name: 'count', dataType: DataType.int64),
      FieldSchema(name: 'score_val', dataType: DataType.float64),
      FieldSchema(name: 'active', dataType: DataType.bool_),
    ],
  );
}

/// Helper: create a populated collection with test data and return it.
/// Caller is responsible for closing and cleaning up.
(Collection, Directory) _createPopulatedCollection() {
  final dir = _createTempDir('populated');
  final schema = _createTestSchema();
  final collection = Collection.createAndOpen(_dbPath(dir), schema);
  schema.destroy();

  // Insert 10 documents
  final rng = Random(42);
  final docs = <Doc>[];
  for (var i = 0; i < 10; i++) {
    final vec = Float32List.fromList(List.generate(4, (_) => rng.nextDouble()));
    final doc = Doc(id: 'pk_$i')
      ..setField('title', 'Document #$i')
      ..setField('count', i * 10)
      ..setField('score_val', i * 1.5)
      ..setField('active', i % 2 == 0)
      ..setVector('embedding', vec);
    docs.add(doc);
  }
  final insertResult = collection.insert(docs);
  for (final doc in docs) {
    doc.destroy();
  }

  if (insertResult.successCount != docs.length ||
      insertResult.errorCount != 0) {
    final details = insertResult.errors.join('; ');
    try {
      collection.close();
    } catch (_) {}
    _cleanupDir(dir);
    fail(
      '_createPopulatedCollection failed to insert seed docs: '
      '$insertResult, expected success=${docs.length}, error=0, '
      'details=[$details]',
    );
  }

  collection.optimize();
  return (collection, dir);
}

/// Helper: create a collection with two searchable vector fields.
(Collection, Directory) _createMultiVectorCollection() {
  final dir = _createTempDir('multi_vector');
  final schema = CollectionSchema(
    name: 'multi_vector_collection',
    fields: [
      VectorSchema('title_embedding', 4, indexParams: FlatIndexParams()),
      VectorSchema('body_embedding', 4, indexParams: FlatIndexParams()),
      FieldSchema(name: 'title', dataType: DataType.string),
      FieldSchema(name: 'rank', dataType: DataType.int64),
    ],
  );
  final collection = Collection.createAndOpen(_dbPath(dir), schema);
  schema.destroy();

  final titleNeedle = Float32List.fromList([1.0, 0.0, 0.0, 0.0]);
  final bodyNeedle = Float32List.fromList([0.0, 1.0, 0.0, 0.0]);
  final other = Float32List.fromList([0.0, 0.0, 1.0, 0.0]);
  final far = Float32List.fromList([0.0, 0.0, 0.0, 1.0]);

  final docs = [
    Doc(id: 'pk_both')
      ..setField('title', 'Both fields')
      ..setField('rank', 10)
      ..setVector('title_embedding', titleNeedle)
      ..setVector('body_embedding', bodyNeedle),
    Doc(id: 'pk_title')
      ..setField('title', 'Title field')
      ..setField('rank', 20)
      ..setVector('title_embedding', titleNeedle)
      ..setVector('body_embedding', other),
    Doc(id: 'pk_body')
      ..setField('title', 'Body field')
      ..setField('rank', 30)
      ..setVector('title_embedding', other)
      ..setVector('body_embedding', bodyNeedle),
    Doc(id: 'pk_far')
      ..setField('title', 'Far field')
      ..setField('rank', 40)
      ..setVector('title_embedding', far)
      ..setVector('body_embedding', far),
  ];

  final insertResult = collection.insert(docs);
  for (final doc in docs) {
    doc.destroy();
  }

  if (insertResult.successCount != docs.length ||
      insertResult.errorCount != 0) {
    final details = insertResult.errors.join('; ');
    try {
      collection.close();
    } catch (_) {}
    _cleanupDir(dir);
    fail(
      '_createMultiVectorCollection failed to insert seed docs: '
      '$insertResult, expected success=${docs.length}, error=0, '
      'details=[$details]',
    );
  }

  collection.optimize();
  return (collection, dir);
}

/// Helper: create a collection with one vector field and one FTS field.
(Collection, Directory) _createVectorFtsCollection() {
  final dir = _createTempDir('vector_fts');
  final content = FieldSchema(
    name: 'content',
    dataType: DataType.string,
    nullable: false,
  );
  final ftsIndexParams = FtsIndexParams(
    tokenizerName: 'jieba',
    filters: ['lowercase'],
  );
  content.setIndexParams(ftsIndexParams);

  final schema = CollectionSchema(
    name: 'vector_fts_collection',
    fields: [
      VectorSchema('embedding', 4, indexParams: FlatIndexParams()),
      FieldSchema(name: 'title', dataType: DataType.string),
      content,
    ],
  );
  final collection = Collection.createAndOpen(_dbPath(dir), schema);
  schema.destroy();
  content.destroy();
  ftsIndexParams.destroy();

  final vectorNeedle = Float32List.fromList([1.0, 0.0, 0.0, 0.0]);
  final far = Float32List.fromList([0.0, 0.0, 0.0, 1.0]);

  final docs = [
    Doc(id: 'pk_both')
      ..setField('title', 'Vector and FTS')
      ..setField('content', '中华人民共和国成立')
      ..setVector('embedding', vectorNeedle),
    Doc(id: 'pk_vector')
      ..setField('title', 'Vector only')
      ..setField('content', '无关文档')
      ..setVector('embedding', vectorNeedle),
    Doc(id: 'pk_fts')
      ..setField('title', 'FTS only')
      ..setField('content', '中华文化源远流长')
      ..setVector('embedding', far),
    Doc(id: 'pk_far')
      ..setField('title', 'Far')
      ..setField('content', '完全不同')
      ..setVector('embedding', far),
  ];

  final insertResult = collection.insert(docs);
  for (final doc in docs) {
    doc.destroy();
  }

  if (insertResult.successCount != docs.length ||
      insertResult.errorCount != 0) {
    final details = insertResult.errors.join('; ');
    try {
      collection.close();
    } catch (_) {}
    _cleanupDir(dir);
    fail(
      '_createVectorFtsCollection failed to insert seed docs: '
      '$insertResult, expected success=${docs.length}, error=0, '
      'details=[$details]',
    );
  }

  collection.optimize();
  return (collection, dir);
}

void main() {
  // Single initialization for the whole test suite.
  // Zvec.shutdown() / re-initialize cycles can block, so we initialize once.
  setUpAll(() => Zvec.initialize());
  tearDownAll(() => Zvec.shutdown());

  // =========================================================================
  // Task 4: Zvec lifecycle and config
  // =========================================================================
  group('Zvec lifecycle', () {
    test('isInitialized is true after initialize', () {
      expect(Zvec.isInitialized, isTrue);
    });

    test('version is non-empty string', () {
      expect(Zvec.version, isNotEmpty);
      expect(Zvec.versionMajor, greaterThanOrEqualTo(0));
      expect(Zvec.versionMinor, greaterThanOrEqualTo(0));
      expect(Zvec.versionPatch, greaterThanOrEqualTo(0));
    });

    test('checkVersion with current version returns true', () {
      final major = Zvec.versionMajor;
      final minor = Zvec.versionMinor;
      final patch = Zvec.versionPatch;
      expect(Zvec.checkVersion(major, minor, patch), isTrue);
    });
  });

  group('ConfigData', () {
    test('create and set properties', () {
      final config = ConfigData();

      config.setMemoryLimit(1024 * 1024 * 512); // 512 MB
      expect(config.memoryLimit, 1024 * 1024 * 512);

      config.setQueryThreadCount(4);
      expect(config.queryThreadCount, 4);

      config.setOptimizeThreadCount(2);
      expect(config.optimizeThreadCount, 2);

      config.destroy();
    });

    test('destroy sets internal state to null', () {
      final config = ConfigData();
      config.destroy();
      // Accessing after destroy should throw StateError
      expect(() => config.memoryLimit, throwsStateError);
    });

    test('setJiebaDictDir round-trips value', () {
      final config = ConfigData();
      config.setJiebaDictDir('/tmp/jieba_dict');
      expect(config.jiebaDictDir, '/tmp/jieba_dict');
      config.destroy();
    });

    test('bundled Jieba dict dir is registered by default', () {
      final dir = Zvec.defaultJiebaDictDir;
      expect(dir, isNotNull);
      expect(File('$dir/jieba.dict.utf8').existsSync(), isTrue);
      expect(File('$dir/hmm_model.utf8').existsSync(), isTrue);
    });

    test('setDefaultJiebaDictDir round-trips global value', () {
      final previous = Zvec.defaultJiebaDictDir;
      try {
        Zvec.setDefaultJiebaDictDir('/tmp/zvec_jieba_default');
        expect(Zvec.defaultJiebaDictDir, '/tmp/zvec_jieba_default');
      } finally {
        Zvec.setDefaultJiebaDictDir(previous ?? '');
      }
    });

    test('setFtsBruteForceByKeysRatio round-trips value', () {
      final config = ConfigData();
      config.setFtsBruteForceByKeysRatio(0.25);
      expect(config.ftsBruteForceByKeysRatio, closeTo(0.25, 1e-6));
      config.destroy();
    });
  });

  group('LogConfig', () {
    test('console log config creation', () {
      final log = LogConfig.console(level: LogLevel.debug);
      expect(log.nativePtr, isNotNull);
      log.destroy();
    });

    test('file log config creation', () {
      final tmpDir = _createTempDir('logconfig');
      try {
        final log = LogConfig.file(
          level: LogLevel.warn,
          directory: tmpDir.path,
          basename: 'test_log',
          fileSizeMb: 50,
          overdueDays: 3,
        );
        expect(log.nativePtr, isNotNull);
        log.destroy();
      } finally {
        _cleanupDir(tmpDir);
      }
    });
  });

  group('ConfigData with LogConfig', () {
    test('custom config can be created and configured', () {
      final config = ConfigData();
      config.setQueryThreadCount(2);
      final log = LogConfig.console(level: LogLevel.warn);
      config.setLogConfig(log);
      // LogConfig ownership transferred — do NOT destroy log

      // Verify config was built without error
      expect(config.queryThreadCount, 2);
      config.destroy();
    });
  });

  // =========================================================================
  // Task 5: Schema and field tests
  // =========================================================================
  group('FieldSchema', () {
    test('scalar field properties', () {
      final field = FieldSchema(
        name: 'title',
        dataType: DataType.string,
        nullable: true,
      );
      expect(field.name, 'title');
      expect(field.dataType, DataType.string);
      expect(field.isNullable, isTrue);
      expect(field.dimension, 0);
      expect(field.isVectorField, isFalse);
      expect(field.isDenseVector, isFalse);
      expect(field.isSparseVector, isFalse);
      expect(field.hasIndex, isFalse);
      field.destroy();
    });

    test('vector field properties', () {
      final field = FieldSchema(
        name: 'vec',
        dataType: DataType.vectorFp32,
        nullable: false,
        dimension: 128,
      );
      expect(field.name, 'vec');
      expect(field.dataType, DataType.vectorFp32);
      expect(field.isNullable, isFalse);
      expect(field.dimension, 128);
      expect(field.isVectorField, isTrue);
      expect(field.isDenseVector, isTrue);
      expect(field.isSparseVector, isFalse);
      field.destroy();
    });

    test('setIndexParams attaches index', () {
      final field = FieldSchema(
        name: 'vec',
        dataType: DataType.vectorFp32,
        dimension: 64,
      );
      expect(field.hasIndex, isFalse);

      final params = HnswIndexParams(m: 32, efConstruction: 100);
      field.setIndexParams(params);
      expect(field.hasIndex, isTrue);
      expect(field.indexType, IndexType.hnsw);

      params.destroy();
      field.destroy();
    });
  });

  group('VectorSchema', () {
    test('creates vector field with correct defaults', () {
      final vs = VectorSchema('embed', 256);
      expect(vs.name, 'embed');
      expect(vs.dataType, DataType.vectorFp32);
      expect(vs.dimension, 256);
      expect(vs.isNullable, isFalse);
      expect(vs.isVectorField, isTrue);
      vs.destroy();
    });

    test('auto-sets index params', () {
      final vs = VectorSchema('embed', 128, indexParams: HnswIndexParams());
      expect(vs.hasIndex, isTrue);
      expect(vs.indexType, IndexType.hnsw);
      vs.destroy();
    });
  });

  group('CollectionSchema', () {
    test('create with name and fields', () {
      final schema = CollectionSchema(
        name: 'my_coll',
        fields: [FieldSchema(name: 'f1', dataType: DataType.string)],
      );
      expect(schema.name, 'my_coll');
      expect(schema.hasField('f1'), isTrue);
      expect(schema.hasField('nonexistent'), isFalse);
      schema.destroy();
    });

    test('name getter/setter', () {
      final schema = CollectionSchema(name: 'old_name');
      expect(schema.name, 'old_name');
      schema.name = 'new_name';
      expect(schema.name, 'new_name');
      schema.destroy();
    });

    test('addField and getField', () {
      final schema = CollectionSchema(name: 'test');
      final field = FieldSchema(name: 'age', dataType: DataType.int64);
      schema.addField(field);
      field.destroy();

      expect(schema.hasField('age'), isTrue);
      final retrieved = schema.getField('age');
      expect(retrieved, isNotNull);
      expect(retrieved!.name, 'age');
      expect(retrieved.dataType, DataType.int64);
      // Non-owning pointer — do not destroy retrieved
      schema.destroy();
    });

    test('getField returns null for unknown field', () {
      final schema = CollectionSchema(name: 'test');
      expect(schema.getField('unknown'), isNull);
      schema.destroy();
    });

    test('dropField removes field', () {
      final schema = CollectionSchema(
        name: 'test',
        fields: [
          FieldSchema(name: 'f1', dataType: DataType.string),
          FieldSchema(name: 'f2', dataType: DataType.int64),
        ],
      );
      expect(schema.hasField('f1'), isTrue);
      schema.dropField('f1');
      expect(schema.hasField('f1'), isFalse);
      expect(schema.hasField('f2'), isTrue);
      schema.destroy();
    });

    test('addIndex and dropIndex on field', () {
      // Use a scalar field to test addIndex / dropIndex clearly
      final schema = CollectionSchema(
        name: 'test',
        fields: [FieldSchema(name: 'title', dataType: DataType.string)],
      );
      final field = schema.getField('title');
      expect(field, isNotNull);
      expect(field!.hasIndex, isFalse);

      final params = InvertIndexParams();
      schema.addIndex('title', params);
      params.destroy();

      final fieldAfter = schema.getField('title');
      expect(fieldAfter!.hasIndex, isTrue);

      schema.dropIndex('title');
      final fieldAfterDrop = schema.getField('title');
      expect(fieldAfterDrop!.hasIndex, isFalse);
      schema.destroy();
    });

    test('validate passes for valid schema', () {
      final schema = _createTestSchema();
      expect(() => schema.validate(), returnsNormally);
      schema.destroy();
    });
  });

  // =========================================================================
  // Task 6: Collection lifecycle and options
  // =========================================================================
  group('CollectionOptions', () {
    test('default options', () {
      final opts = CollectionOptions();
      // Just verify getters don't throw
      opts.enableMmap;
      opts.maxBufferSize;
      opts.readOnly;
      opts.destroy();
    });

    test('set and get properties', () {
      final opts = CollectionOptions();
      opts.enableMmap = true;
      expect(opts.enableMmap, isTrue);
      opts.enableMmap = false;
      expect(opts.enableMmap, isFalse);

      opts.readOnly = true;
      expect(opts.readOnly, isTrue);
      opts.destroy();
    });

    test('destroy sets internal state to null', () {
      final opts = CollectionOptions();
      opts.destroy();
      expect(() => opts.enableMmap, throwsStateError);
    });
  });

  group('Collection lifecycle', () {
    test('createAndOpen then close', () {
      final dir = _createTempDir('lifecycle');
      try {
        final schema = _createTestSchema();
        final collection = Collection.createAndOpen(_dbPath(dir), schema);
        schema.destroy();
        collection.close();
      } finally {
        _cleanupDir(dir);
      }
    });

    test('open existing collection', () {
      final dir = _createTempDir('reopen');
      try {
        // Create
        final schema = _createTestSchema();
        final c1 = Collection.createAndOpen(_dbPath(dir), schema);
        schema.destroy();
        c1.close();

        // Re-open
        final c2 = Collection.open(_dbPath(dir));
        c2.close();
      } finally {
        _cleanupDir(dir);
      }
    });

    test('flush does not throw', () {
      final dir = _createTempDir('flush');
      try {
        final schema = _createTestSchema();
        final collection = Collection.createAndOpen(_dbPath(dir), schema);
        schema.destroy();
        expect(() => collection.flush(), returnsNormally);
        collection.close();
      } finally {
        _cleanupDir(dir);
      }
    });

    test('optimize does not throw', () {
      final dir = _createTempDir('optimize');
      try {
        final schema = _createTestSchema();
        final collection = Collection.createAndOpen(_dbPath(dir), schema);
        schema.destroy();
        expect(() => collection.optimize(), returnsNormally);
        collection.close();
      } finally {
        _cleanupDir(dir);
      }
    });

    test('schema/options/stats accessors', () {
      final dir = _createTempDir('accessors');
      try {
        final schema = _createTestSchema();
        final collection = Collection.createAndOpen(_dbPath(dir), schema);
        schema.destroy();

        final s = collection.schema;
        expect(s.name, 'test_collection');
        s.destroy();

        final o = collection.options;
        o.destroy();

        final st = collection.stats;
        expect(st.docCount, 0);
        st.destroy();

        collection.close();
      } finally {
        _cleanupDir(dir);
      }
    });
  });

  // =========================================================================
  // Task 7: Doc operations
  // =========================================================================
  group('Doc', () {
    test('default constructor creates empty doc', () {
      final doc = Doc();
      expect(doc.isEmpty, isTrue);
      expect(doc.fieldCount, 0);
      doc.destroy();
    });

    test('constructor with id', () {
      final doc = Doc(id: 'my_pk');
      expect(doc.pk, 'my_pk');
      doc.destroy();
    });

    test('pk getter/setter', () {
      final doc = Doc();
      // A fresh Doc without id may return null or empty string depending on native impl
      expect(doc.pk, anyOf(isNull, isEmpty));
      doc.pk = 'test_pk';
      expect(doc.pk, 'test_pk');
      doc.destroy();
    });

    test('constructor with fields map', () {
      final doc = Doc(
        id: 'pk1',
        fields: {
          'name': 'Alice',
          'age': 30,
          'height': 1.65,
          'active': true,
          'vec': Float32List.fromList([1.0, 2.0, 3.0]),
        },
      );
      expect(doc.pk, 'pk1');
      expect(doc.getString('name'), 'Alice');
      expect(doc.getInt64('age'), 30);
      expect(doc.getDouble('height'), closeTo(1.65, 0.001));
      expect(doc.getBool('active'), isTrue);
      expect(doc.getVector('vec'), isNotNull);
      expect(doc.getVector('vec')!.length, 3);
      doc.destroy();
    });

    test('setField and getters for all scalar types', () {
      final doc = Doc();
      doc.setField('s', 'hello');
      doc.setField('i', 42);
      doc.setField('d', 3.14);
      doc.setField('b', false);

      expect(doc.getString('s'), 'hello');
      expect(doc.getInt64('i'), 42);
      expect(doc.getDouble('d'), closeTo(3.14, 0.001));
      expect(doc.getBool('b'), isFalse);
      doc.destroy();
    });

    test('setField throws for unsupported type', () {
      final doc = Doc();
      expect(() => doc.setField('x', [1, 2, 3]), throwsArgumentError);
      doc.destroy();
    });

    test('setVector and getVector round-trip', () {
      final doc = Doc();
      final vec = Float32List.fromList([0.1, 0.2, 0.3, 0.4]);
      doc.setVector('v', vec);
      final result = doc.getVector('v');
      expect(result, isNotNull);
      expect(result!.length, 4);
      for (var i = 0; i < 4; i++) {
        expect(result[i], closeTo(vec[i], 1e-6));
      }
      doc.destroy();
    });

    test('setVector64 for FP64 vectors', () {
      final doc = Doc();
      final vec = Float64List.fromList([1.1, 2.2, 3.3]);
      doc.setVector64('v64', vec);
      expect(doc.hasField('v64'), isTrue);
      doc.destroy();
    });

    test('hasField and fieldCount', () {
      final doc = Doc();
      expect(doc.hasField('x'), isFalse);
      doc.setField('x', 'val');
      expect(doc.hasField('x'), isTrue);
      expect(doc.fieldCount, greaterThan(0));
      doc.destroy();
    });

    test('setFieldNull and isFieldNull', () {
      final doc = Doc();
      doc.setField('s', 'hello');
      expect(doc.isFieldNull('s'), isFalse);
      doc.setFieldNull('s');
      expect(doc.isFieldNull('s'), isTrue);
      // Getter should return null for null field
      expect(doc.getString('s'), isNull);
      doc.destroy();
    });

    test('fieldNames returns list of field names', () {
      final doc = Doc();
      doc.setField('alpha', 'a');
      doc.setField('beta', 42);
      final names = doc.fieldNames;
      expect(names, containsAll(['alpha', 'beta']));
      doc.destroy();
    });

    test('getters return null for non-existent fields', () {
      final doc = Doc();
      expect(doc.getString('nope'), isNull);
      expect(doc.getInt64('nope'), isNull);
      expect(doc.getDouble('nope'), isNull);
      expect(doc.getBool('nope'), isNull);
      expect(doc.getVector('nope'), isNull);
      doc.destroy();
    });

    test('toString format', () {
      final doc = Doc(id: 'pk1');
      doc.setField('a', 'b');
      final s = doc.toString();
      expect(s, contains('pk=pk1'));
      expect(s, contains('Doc('));
      doc.destroy();
    });
  });

  // =========================================================================
  // Task 8: DML operations (insert/update/upsert/delete)
  // =========================================================================
  group('Collection DML', () {
    test('insert returns correct WriteResult', () {
      final (collection, dir) = _createPopulatedCollection();
      try {
        // Already inserted 10 docs in helper
        final fetched = collection.fetch(['pk_0', 'pk_9']);
        expect(fetched.length, 2);
        collection.close();
      } finally {
        _cleanupDir(dir);
      }
    });

    test('update modifies existing documents', () {
      final (collection, dir) = _createPopulatedCollection();
      try {
        final doc = Doc(id: 'pk_0')..setField('title', 'Updated Title');
        final result = collection.update([doc]);
        doc.destroy();
        expect(result.successCount, 1);

        final fetched = collection.fetch(['pk_0']);
        expect(fetched.length, 1);
        expect(fetched[0].getString('title'), 'Updated Title');
        collection.close();
      } finally {
        _cleanupDir(dir);
      }
    });

    test('upsert inserts new and updates existing', () {
      final (collection, dir) = _createPopulatedCollection();
      try {
        // Upsert: update existing pk_0 + insert new pk_new
        final vec = Float32List.fromList([0.5, 0.5, 0.5, 0.5]);
        final docs = [
          Doc(id: 'pk_0')
            ..setField('title', 'Upserted')
            ..setVector('embedding', vec),
          Doc(id: 'pk_new')
            ..setField('title', 'Brand New')
            ..setVector('embedding', vec),
        ];
        final result = collection.upsert(docs);
        for (final d in docs) {
          d.destroy();
        }
        expect(result.successCount, 2);
        expect(result.isAllSuccess, isTrue);

        final fetched = collection.fetch(['pk_0', 'pk_new']);
        expect(fetched.length, 2);
        collection.close();
      } finally {
        _cleanupDir(dir);
      }
    });

    test('delete by primary keys', () {
      final (collection, dir) = _createPopulatedCollection();
      try {
        final result = collection.delete(['pk_0', 'pk_1']);
        expect(result.successCount, 2);
        expect(result.isAllSuccess, isTrue);

        final fetched = collection.fetch(['pk_0', 'pk_1']);
        expect(fetched.length, 0);
        collection.close();
      } finally {
        _cleanupDir(dir);
      }
    });

    test('deleteByFilter removes matching docs', () {
      final (collection, dir) = _createPopulatedCollection();
      try {
        // Delete docs where count >= 50 (pk_5..pk_9 → 5 docs)
        collection.deleteByFilter('count >= 50');
        collection.optimize();

        final stats = collection.stats;
        expect(stats.docCount, 5);
        stats.destroy();
        collection.close();
      } finally {
        _cleanupDir(dir);
      }
    });

    test('WriteResult end-to-end', () {
      final dir = _createTempDir('writeresult');
      try {
        final schema = _createTestSchema();
        final collection = Collection.createAndOpen(_dbPath(dir), schema);
        schema.destroy();

        final vec = Float32List.fromList([1.0, 2.0, 3.0, 4.0]);
        final docs = [
          Doc(id: 'a')
            ..setField('title', 'A')
            ..setVector('embedding', vec),
          Doc(id: 'b')
            ..setField('title', 'B')
            ..setVector('embedding', vec),
        ];
        final result = collection.insert(docs);
        for (final d in docs) {
          d.destroy();
        }

        expect(result.successCount, 2);
        expect(result.errorCount, 0);
        expect(result.totalCount, 2);
        expect(result.isAllSuccess, isTrue);
        collection.close();
      } finally {
        _cleanupDir(dir);
      }
    });
  });

  // =========================================================================
  // Task 9: Query and fetch tests
  // =========================================================================
  group('VectorQuery', () {
    late Collection collection;
    late Directory tmpDir;

    setUpAll(() {
      final result = _createPopulatedCollection();
      collection = result.$1;
      tmpDir = result.$2;
    });

    tearDownAll(() {
      try {
        collection.close();
      } catch (_) {}
      _cleanupDir(tmpDir);
    });

    test('basic vector search returns results', () {
      final query = VectorQuery(
        fieldName: 'embedding',
        vector: Float32List.fromList([0.5, 0.5, 0.5, 0.5]),
        topk: 5,
      );
      final results = collection.query(query);
      query.destroy();

      expect(results, isNotEmpty);
      expect(results.length, lessThanOrEqualTo(5));
      // Results should have pk and score
      for (final doc in results) {
        expect(doc.pk, isNotNull);
        expect(doc.score, isNotNull);
      }
    });

    test('query with outputFields', () {
      final query = VectorQuery(
        fieldName: 'embedding',
        vector: Float32List.fromList([0.1, 0.2, 0.3, 0.4]),
        topk: 3,
        outputFields: ['title'],
      );
      final results = collection.query(query);
      query.destroy();

      expect(results, isNotEmpty);
      for (final doc in results) {
        expect(doc.getString('title'), isNotNull);
      }
    });

    test('query with filter', () {
      final query = VectorQuery(
        fieldName: 'embedding',
        vector: Float32List.fromList([0.5, 0.5, 0.5, 0.5]),
        topk: 10,
        filter: 'count >= 50',
        outputFields: ['count'],
      );
      final results = collection.query(query);
      query.destroy();

      // All results should have count >= 50
      for (final doc in results) {
        expect(doc.getInt64('count'), greaterThanOrEqualTo(50));
      }
    });

    test('query with includeVector returns vector data', () {
      final query = VectorQuery(
        fieldName: 'embedding',
        vector: Float32List.fromList([0.1, 0.2, 0.3, 0.4]),
        topk: 2,
        includeVector: true,
      );
      final results = collection.query(query);
      query.destroy();

      expect(results, isNotEmpty);
      for (final doc in results) {
        final vec = doc.getVector('embedding');
        expect(vec, isNotNull);
        expect(vec!.length, 4);
      }
    });

    test('query with HnswQueryParams', () {
      final qp = HnswQueryParams(ef: 100);
      final query = VectorQuery(
        fieldName: 'embedding',
        vector: Float32List.fromList([0.5, 0.5, 0.5, 0.5]),
        topk: 3,
        queryParams: qp,
      );
      final results = collection.query(query);
      query.destroy();
      expect(results, isNotEmpty);
    });
  });

  group('Collection.fetch', () {
    late Collection collection;
    late Directory tmpDir;

    setUpAll(() {
      final result = _createPopulatedCollection();
      collection = result.$1;
      tmpDir = result.$2;
    });

    tearDownAll(() {
      try {
        collection.close();
      } catch (_) {}
      _cleanupDir(tmpDir);
    });

    test('fetch existing PKs returns documents', () {
      final docs = collection.fetch(['pk_0', 'pk_5']);
      expect(docs.length, 2);
    });

    test('fetch non-existing PK returns empty', () {
      final docs = collection.fetch(['nonexistent_pk']);
      expect(docs, isEmpty);
    });

    test('fetch mixed existing and non-existing', () {
      final docs = collection.fetch(['pk_0', 'not_here', 'pk_9']);
      expect(docs.length, 2);
    });
  });

  // =========================================================================
  // Task 10: Index params, query params, column management
  // =========================================================================
  group('IndexParams', () {
    test('HnswIndexParams defaults', () {
      final p = HnswIndexParams();
      expect(p.indexType, IndexType.hnsw);
      expect(p.metricType, MetricType.cosine);
      expect(p.m, 16);
      expect(p.efConstruction, 200);
      p.destroy();
    });

    test('HnswIndexParams custom values', () {
      final p = HnswIndexParams(
        m: 32,
        efConstruction: 400,
        metricType: MetricType.l2,
        quantizeType: QuantizeType.fp16,
      );
      expect(p.m, 32);
      expect(p.efConstruction, 400);
      expect(p.metricType, MetricType.l2);
      expect(p.quantizeType, QuantizeType.fp16);
      p.destroy();
    });

    test('IVFIndexParams', () {
      final p = IVFIndexParams(nList: 50, metricType: MetricType.ip);
      expect(p.indexType, IndexType.ivf);
      expect(p.metricType, MetricType.ip);
      p.destroy();
    });

    test('FlatIndexParams', () {
      final p = FlatIndexParams(metricType: MetricType.l2);
      expect(p.indexType, IndexType.flat);
      expect(p.metricType, MetricType.l2);
      p.destroy();
    });

    test('InvertIndexParams', () {
      final p = InvertIndexParams();
      expect(p.indexType, IndexType.invert);
      p.destroy();
    });
  });

  group('QueryParams', () {
    test('HnswQueryParams default and custom ef', () {
      final p = HnswQueryParams();
      expect(p.ef, 40);

      final p2 = HnswQueryParams(ef: 200);
      expect(p2.ef, 200);
      p2.ef = 300;
      expect(p2.ef, 300);

      p.destroy();
      p2.destroy();
    });

    test('IVFQueryParams', () {
      final p = IVFQueryParams(nprobe: 20);
      expect(p.nprobe, 20);
      p.nprobe = 30;
      expect(p.nprobe, 30);
      p.destroy();
    });

    test('FlatQueryParams', () {
      final p = FlatQueryParams();
      expect(p.nativePtr, isNotNull);
      p.destroy();
    });

    test('FtsQueryParams default operator is OR', () {
      final p = FtsQueryParams();
      expect(p.defaultOperator, 'OR');
      p.destroy();
    });

    test('FtsQueryParams custom operator AND', () {
      final p = FtsQueryParams(defaultOperator: 'AND');
      expect(p.defaultOperator, 'AND');
      p.destroy();
    });

    test('FtsQueryParams setter changes operator', () {
      final p = FtsQueryParams();
      expect(p.defaultOperator, 'OR');
      p.defaultOperator = 'AND';
      expect(p.defaultOperator, 'AND');
      p.destroy();
    });
  });

  group('Collection DDL (column management)', () {
    test('addColumn adds a new field', () {
      final dir = _createTempDir('ddl_add');
      try {
        final schema = _createTestSchema();
        final collection = Collection.createAndOpen(_dbPath(dir), schema);
        schema.destroy();

        // addColumn only supports numeric types (int32/int64/uint32/uint64/float/double)
        final newField = FieldSchema(
          name: 'priority',
          dataType: DataType.int64,
        );
        collection.addColumn(newField);
        newField.destroy();

        final s = collection.schema;
        expect(s.hasField('priority'), isTrue);
        s.destroy();
        collection.close();
      } finally {
        _cleanupDir(dir);
      }
    });

    test('dropColumn removes a field', () {
      final dir = _createTempDir('ddl_drop');
      try {
        final schema = _createTestSchema();
        final collection = Collection.createAndOpen(_dbPath(dir), schema);
        schema.destroy();

        // dropColumn only supports numeric types; drop 'count' (int64)
        collection.dropColumn('count');
        final s = collection.schema;
        expect(s.hasField('count'), isFalse);
        s.destroy();
        collection.close();
      } finally {
        _cleanupDir(dir);
      }
    });

    test('createIndex and dropIndex', () {
      final dir = _createTempDir('ddl_index');
      try {
        // Create collection with a string field that has no index
        final schema = CollectionSchema(
          name: 'idx_test',
          fields: [
            VectorSchema('embedding', 4, indexParams: HnswIndexParams()),
            FieldSchema(name: 'title', dataType: DataType.string),
          ],
        );
        final collection = Collection.createAndOpen(_dbPath(dir), schema);
        schema.destroy();

        // Add an invert index on 'title'
        final params = InvertIndexParams();
        collection.createIndex('title', params);
        params.destroy();

        // Verify index exists
        final s = collection.schema;
        final f = s.getField('title');
        expect(f!.hasIndex, isTrue);
        s.destroy();

        // Drop the index
        collection.dropIndex('title');
        final s2 = collection.schema;
        final f2 = s2.getField('title');
        expect(f2!.hasIndex, isFalse);
        s2.destroy();

        collection.close();
      } finally {
        _cleanupDir(dir);
      }
    });
  });

  // =========================================================================
  // Task 11: CollectionStats and error handling
  // =========================================================================
  group('CollectionStats', () {
    test('docCount reflects inserted documents', () {
      final (collection, dir) = _createPopulatedCollection();
      try {
        final stats = collection.stats;
        expect(stats.docCount, 10);
        stats.destroy();
        collection.close();
      } finally {
        _cleanupDir(dir);
      }
    });

    test('indexCount after optimize', () {
      final (collection, dir) = _createPopulatedCollection();
      try {
        final stats = collection.stats;
        expect(stats.indexCount, greaterThan(0));

        // Verify getIndexName and getIndexCompleteness
        for (var i = 0; i < stats.indexCount; i++) {
          expect(stats.getIndexName(i), isNotEmpty);
          expect(stats.getIndexCompleteness(i), greaterThanOrEqualTo(0.0));
        }
        stats.destroy();
        collection.close();
      } finally {
        _cleanupDir(dir);
      }
    });

    test('indexes computed map', () {
      final (collection, dir) = _createPopulatedCollection();
      try {
        final stats = collection.stats;
        final indexes = stats.indexes;
        expect(indexes, isNotEmpty);
        for (final entry in indexes.entries) {
          expect(entry.key, isNotEmpty);
          expect(entry.value, greaterThanOrEqualTo(0.0));
        }
        stats.destroy();
        collection.close();
      } finally {
        _cleanupDir(dir);
      }
    });
  });

  group('Error handling', () {
    test('open non-existent collection throws ZvecException', () {
      expect(
        () => Collection.open('/tmp/zvec_test_does_not_exist_12345'),
        throwsA(isA<ZvecException>()),
      );
    });

    test('ZvecException contains error code', () {
      try {
        Collection.open('/tmp/zvec_test_does_not_exist_12345');
        fail('Expected ZvecException');
      } on ZvecException catch (e) {
        // Should be a meaningful error code (not ok)
        expect(e.code, isNot(ZvecErrorCode.ok));
        expect(e.toString(), contains('ZvecException'));
      }
    });
  });

  // =========================================================================
  // Task 12: FTS and MultiQuery — new in 0.5.0
  // =========================================================================
  group('FtsQuery', () {
    test('create with queryString', () {
      final fts = FtsQuery(queryString: 'title:flutter AND body:dart');
      expect(fts.queryString, 'title:flutter AND body:dart');
      expect(fts.matchString, isNull);
      fts.destroy();
    });

    test('create with matchString', () {
      final fts = FtsQuery(matchString: '如何使用向量数据库');
      expect(fts.matchString, '如何使用向量数据库');
      expect(fts.queryString, isNull);
      fts.destroy();
    });

    test('create with both queryString and matchString', () {
      final fts = FtsQuery(
        queryString: 'title:flutter',
        matchString: 'vector database',
      );
      expect(fts.queryString, 'title:flutter');
      expect(fts.matchString, 'vector database');
      fts.destroy();
    });

    test('create empty FtsQuery', () {
      final fts = FtsQuery();
      expect(fts.queryString, isNull);
      expect(fts.matchString, isNull);
      fts.destroy();
    });

    test('nativePtr is not null', () {
      final fts = FtsQuery(queryString: 'test');
      expect(fts.nativePtr, isNotNull);
      fts.destroy();
    });
  });

  group('FtsIndexParams', () {
    test('create with tokenizerName only', () {
      final p = FtsIndexParams(tokenizerName: 'standard');
      expect(p.indexType, IndexType.fts);
      p.destroy();
    });

    test('create with tokenizerName and filters', () {
      final p = FtsIndexParams(
        tokenizerName: 'jieba',
        filters: ['lowercase', 'stopwords'],
      );
      expect(p.indexType, IndexType.fts);
      p.destroy();
    });

    test('create with tokenizerName and extraParams', () {
      final p = FtsIndexParams(
        tokenizerName: 'jieba',
        extraParams: '{"mode": "search"}',
      );
      expect(p.indexType, IndexType.fts);
      p.destroy();
    });

    test('create with all parameters', () {
      final p = FtsIndexParams(
        tokenizerName: 'jieba',
        filters: ['lowercase'],
        extraParams: '{"mode": "search"}',
      );
      expect(p.indexType, IndexType.fts);
      expect(p.nativePtr, isNotNull);
      p.destroy();
    });
  });

  group('Jieba FTS end-to-end', () {
    test('queries Chinese text using bundled default dict', () {
      final dir = _createTempDir('jieba_fts');
      Collection? collection;
      try {
        final title = FieldSchema(
          name: 'title',
          dataType: DataType.string,
          nullable: false,
        );
        final content = FieldSchema(
          name: 'content',
          dataType: DataType.string,
          nullable: false,
        );
        final ftsParams = FtsIndexParams(
          tokenizerName: 'jieba',
          filters: ['lowercase'],
        );
        content.setIndexParams(ftsParams);

        final schema = CollectionSchema(name: 'jieba_fts_default');
        schema.addField(title);
        schema.addField(content);
        title.destroy();
        content.destroy();
        ftsParams.destroy();

        collection = Collection.createAndOpen(_dbPath(dir), schema);
        schema.destroy();

        final docs = [
          Doc(id: 'pk_1')
            ..setField('title', 'match')
            ..setField('content', '中华人民共和国成立'),
          Doc(id: 'pk_2')
            ..setField('title', 'miss')
            ..setField('content', '无关文档'),
        ];
        final insertResult = collection.insert(docs);
        for (final doc in docs) {
          doc.destroy();
        }

        if (!insertResult.isAllSuccess) {
          fail('Jieba FTS insert failed: $insertResult');
        }

        final fts = FtsQuery(matchString: '中华');
        final query = VectorQuery.fts(
          fieldName: 'content',
          fts: fts,
          topk: 10,
          outputFields: ['title', 'content'],
        );
        final results = collection.query(query);
        query.destroy();
        fts.destroy();

        final ids = results.map((doc) => doc.pk).toSet();
        expect(ids, contains('pk_1'));
        expect(ids, isNot(contains('pk_2')));
      } finally {
        try {
          collection?.close();
        } catch (_) {}
        _cleanupDir(dir);
      }
    });
  });

  group('SubQuery', () {
    test('create with dense vector', () {
      final sq = SubQuery(
        fieldName: 'embedding',
        vector: Float32List.fromList([0.1, 0.2, 0.3, 0.4]),
      );
      expect(sq.nativePtr, isNotNull);
      sq.destroy();
    });

    test('create with sparse vector', () {
      final sq = SubQuery(
        fieldName: 'sparse_embedding',
        sparseIndices: Uint32List.fromList([0, 5, 10]),
        sparseValues: Float32List.fromList([0.1, 0.5, 0.9]),
      );
      expect(sq.nativePtr, isNotNull);
      sq.destroy();
    });

    test('create with custom numCandidates', () {
      final sq = SubQuery(
        fieldName: 'embedding',
        vector: Float32List.fromList([1.0, 2.0]),
        numCandidates: 200,
      );
      expect(sq.nativePtr, isNotNull);
      sq.destroy();
    });

    test('create with queryParams (HNSW)', () {
      final qp = HnswQueryParams(ef: 150);
      final sq = SubQuery(
        fieldName: 'embedding',
        vector: Float32List.fromList([1.0, 2.0, 3.0]),
        queryParams: qp,
      );
      expect(sq.nativePtr, isNotNull);
      sq.destroy();
      qp.destroy();
    });

    test('create with FTS payload and params', () {
      final fts = FtsQuery(matchString: '中华');
      final qp = FtsQueryParams(defaultOperator: 'AND');
      final sq = SubQuery(fieldName: 'content', fts: fts, ftsParams: qp);
      expect(sq.nativePtr, isNotNull);
      sq.destroy();
      qp.destroy();
      fts.destroy();
    });

    test('rejects vector and FTS payload in one sub-query', () {
      final fts = FtsQuery(matchString: '中华');
      try {
        expect(
          () => SubQuery(
            fieldName: 'content',
            vector: Float32List.fromList([1.0, 0.0, 0.0, 0.0]),
            fts: fts,
          ),
          throwsArgumentError,
        );
      } finally {
        fts.destroy();
      }
    });
  });

  group('MultiQuery', () {
    test('create with single dense sub-query', () {
      final sq = SubQuery(
        fieldName: 'embedding',
        vector: Float32List.fromList([0.1, 0.2, 0.3, 0.4]),
      );
      final mq = MultiQuery(subQueries: [sq], topk: 5);
      expect(mq.nativePtr, isNotNull);
      mq.destroy();
      sq.destroy();
    });

    test('create with filter and outputFields', () {
      final sq = SubQuery(
        fieldName: 'embedding',
        vector: Float32List.fromList([0.5, 0.5, 0.5, 0.5]),
      );
      final mq = MultiQuery(
        subQueries: [sq],
        topk: 10,
        filter: 'count >= 50',
        outputFields: ['title', 'count'],
      );
      expect(mq.nativePtr, isNotNull);
      mq.destroy();
      sq.destroy();
    });

    test('create with includeVector', () {
      final sq = SubQuery(
        fieldName: 'embedding',
        vector: Float32List.fromList([0.1, 0.2, 0.3, 0.4]),
      );
      final mq = MultiQuery(subQueries: [sq], topk: 5, includeVector: true);
      expect(mq.nativePtr, isNotNull);
      mq.destroy();
      sq.destroy();
    });

    test('create with RrfRerank strategy', () {
      final sq1 = SubQuery(
        fieldName: 'embedding',
        vector: Float32List.fromList([0.1, 0.2, 0.3, 0.4]),
      );
      final sq2 = SubQuery(
        fieldName: 'embedding',
        vector: Float32List.fromList([0.5, 0.6, 0.7, 0.8]),
      );
      final mq = MultiQuery(
        subQueries: [sq1, sq2],
        topk: 10,
        rerank: const RrfRerank(rankConstant: 60),
      );
      expect(mq.nativePtr, isNotNull);
      mq.destroy();
      sq1.destroy();
      sq2.destroy();
    });

    test('create with WeightedRerank strategy', () {
      final sq1 = SubQuery(
        fieldName: 'embedding',
        vector: Float32List.fromList([0.1, 0.2, 0.3, 0.4]),
      );
      final sq2 = SubQuery(
        fieldName: 'embedding',
        vector: Float32List.fromList([0.5, 0.6, 0.7, 0.8]),
      );
      final mq = MultiQuery(
        subQueries: [sq1, sq2],
        topk: 10,
        rerank: const WeightedRerank(weights: [0.7, 0.3]),
      );
      expect(mq.nativePtr, isNotNull);
      mq.destroy();
      sq1.destroy();
      sq2.destroy();
    });

    test('create with multiple sub-queries (dense + sparse)', () {
      final sqDense = SubQuery(
        fieldName: 'embedding',
        vector: Float32List.fromList([0.1, 0.2, 0.3, 0.4]),
      );
      final sqSparse = SubQuery(
        fieldName: 'sparse_embedding',
        sparseIndices: Uint32List.fromList([0, 3, 7]),
        sparseValues: Float32List.fromList([0.5, 0.8, 0.2]),
      );
      final mq = MultiQuery(
        subQueries: [sqDense, sqSparse],
        topk: 10,
        rerank: const RrfRerank(),
      );
      expect(mq.nativePtr, isNotNull);
      mq.destroy();
      sqDense.destroy();
      sqSparse.destroy();
    });

    test('executes vector + vector RRF fusion', () {
      final result = _createMultiVectorCollection();
      final collection = result.$1;
      final tmpDir = result.$2;
      final titleSubQuery = SubQuery(
        fieldName: 'title_embedding',
        vector: Float32List.fromList([1.0, 0.0, 0.0, 0.0]),
        numCandidates: 4,
      );
      final bodySubQuery = SubQuery(
        fieldName: 'body_embedding',
        vector: Float32List.fromList([0.0, 1.0, 0.0, 0.0]),
        numCandidates: 4,
      );
      final query = MultiQuery(
        subQueries: [titleSubQuery, bodySubQuery],
        topk: 3,
        outputFields: ['title', 'rank'],
        rerank: const RrfRerank(rankConstant: 60),
      );

      try {
        final results = collection.multiQuery(query);
        final ids = results.map((doc) => doc.pk).toList();

        expect(ids, isNotEmpty);
        expect(ids.first, 'pk_both');
        expect(ids, containsAll(['pk_title', 'pk_body']));
        for (final doc in results) {
          expect(doc.getString('title'), isNotNull);
          expect(doc.getInt64('rank'), isNotNull);
        }
      } finally {
        query.destroy();
        titleSubQuery.destroy();
        bodySubQuery.destroy();
        try {
          collection.close();
        } catch (_) {}
        _cleanupDir(tmpDir);
      }
    });

    test('executes vector + vector weighted fusion with filter', () {
      final result = _createMultiVectorCollection();
      final collection = result.$1;
      final tmpDir = result.$2;
      final titleSubQuery = SubQuery(
        fieldName: 'title_embedding',
        vector: Float32List.fromList([1.0, 0.0, 0.0, 0.0]),
        numCandidates: 4,
      );
      final bodySubQuery = SubQuery(
        fieldName: 'body_embedding',
        vector: Float32List.fromList([0.0, 1.0, 0.0, 0.0]),
        numCandidates: 4,
      );
      final query = MultiQuery(
        subQueries: [titleSubQuery, bodySubQuery],
        topk: 4,
        filter: 'rank < 40',
        includeVector: true,
        outputFields: ['title', 'rank'],
        rerank: const WeightedRerank(weights: [0.8, 0.2]),
      );

      try {
        final results = collection.multiQuery(query);
        final ids = results.map((doc) => doc.pk).toSet();

        expect(ids, isNot(contains('pk_far')));
        expect(ids, containsAll(['pk_both', 'pk_title', 'pk_body']));
        for (final doc in results) {
          expect(doc.getString('title'), isNotNull);
          expect(doc.getInt64('rank'), lessThan(40));
          expect(doc.getVector('title_embedding'), isNotNull);
        }
      } finally {
        query.destroy();
        titleSubQuery.destroy();
        bodySubQuery.destroy();
        try {
          collection.close();
        } catch (_) {}
        _cleanupDir(tmpDir);
      }
    });

    test('executes vector + FTS RRF fusion', () {
      final result = _createVectorFtsCollection();
      final collection = result.$1;
      final tmpDir = result.$2;
      final fts = FtsQuery(matchString: '中华');
      final ftsParams = FtsQueryParams(defaultOperator: 'OR');
      final vectorSubQuery = SubQuery(
        fieldName: 'embedding',
        vector: Float32List.fromList([1.0, 0.0, 0.0, 0.0]),
        numCandidates: 4,
      );
      final ftsSubQuery = SubQuery(
        fieldName: 'content',
        fts: fts,
        ftsParams: ftsParams,
        numCandidates: 4,
      );
      final query = MultiQuery(
        subQueries: [vectorSubQuery, ftsSubQuery],
        topk: 3,
        outputFields: ['title', 'content'],
        rerank: const RrfRerank(rankConstant: 60),
      );

      try {
        final results = collection.multiQuery(query);
        final ids = results.map((doc) => doc.pk).toList();

        expect(ids, isNotEmpty);
        expect(ids.first, 'pk_both');
        expect(ids, containsAll(['pk_vector', 'pk_fts']));
        expect(ids, isNot(contains('pk_far')));
        for (final doc in results) {
          expect(doc.getString('title'), isNotNull);
          expect(doc.getString('content'), isNotNull);
        }
      } finally {
        query.destroy();
        vectorSubQuery.destroy();
        ftsSubQuery.destroy();
        ftsParams.destroy();
        fts.destroy();
        try {
          collection.close();
        } catch (_) {}
        _cleanupDir(tmpDir);
      }
    });
  });

  group('VectorQuery FTS-only', () {
    test('create FTS VectorQuery with fts parameter', () {
      final fts = FtsQuery(queryString: 'flutter dart');
      final query = VectorQuery.fts(fieldName: 'content', topk: 10, fts: fts);
      expect(query.nativePtr, isNotNull);
      query.destroy();
      fts.destroy();
    });

    test('create FTS VectorQuery with fts and ftsParams', () {
      final fts = FtsQuery(matchString: '向量搜索');
      final ftsParams = FtsQueryParams(defaultOperator: 'AND');
      final query = VectorQuery.fts(
        fieldName: 'content',
        topk: 5,
        fts: fts,
        ftsParams: ftsParams,
      );
      expect(query.nativePtr, isNotNull);
      query.destroy();
      fts.destroy();
      ftsParams.destroy();
    });

    test('create FTS VectorQuery with fts, ftsParams, and filter', () {
      final fts = FtsQuery(queryString: 'title:hello');
      final ftsParams = FtsQueryParams();
      final query = VectorQuery.fts(
        fieldName: 'content',
        topk: 3,
        filter: 'count >= 10',
        outputFields: ['title'],
        fts: fts,
        ftsParams: ftsParams,
      );
      expect(query.nativePtr, isNotNull);
      query.destroy();
      fts.destroy();
      ftsParams.destroy();
    });
  });

  group('Collection.fetch new signature', () {
    late Collection collection;
    late Directory tmpDir;

    setUpAll(() {
      final result = _createPopulatedCollection();
      collection = result.$1;
      tmpDir = result.$2;
    });

    tearDownAll(() {
      try {
        collection.close();
      } catch (_) {}
      _cleanupDir(tmpDir);
    });

    test('fetch with outputFields returns specified fields', () {
      final docs = collection.fetch(['pk_0', 'pk_1'], outputFields: ['title']);
      expect(docs.length, 2);
      for (final doc in docs) {
        expect(doc.getString('title'), isNotNull);
      }
    });

    test('fetch with includeVector returns vector data', () {
      final docs = collection.fetch(['pk_0'], includeVector: true);
      expect(docs.length, 1);
      final vec = docs[0].getVector('embedding');
      expect(vec, isNotNull);
      expect(vec!.length, 4);
    });

    test('fetch with outputFields and includeVector', () {
      final docs = collection.fetch(
        ['pk_0', 'pk_5'],
        outputFields: ['title', 'count'],
        includeVector: true,
      );
      expect(docs.length, 2);
      for (final doc in docs) {
        expect(doc.getString('title'), isNotNull);
        final vec = doc.getVector('embedding');
        expect(vec, isNotNull);
        expect(vec!.length, 4);
      }
    });

    test('fetch without optional params still works', () {
      final docs = collection.fetch(['pk_0']);
      expect(docs.length, 1);
    });
  });
}
