import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zvec/zvec.dart';

void main() {
  test('published package loads native library and runs a vector query', () {
    Zvec.initialize();
    final dir = Directory.systemTemp.createTempSync('zvec_release_smoke_');

    Collection? collection;
    CollectionSchema? schema;
    VectorQuery? query;

    try {
      schema = CollectionSchema(
        name: 'release_smoke',
        fields: [
          VectorSchema('embedding', 4, indexParams: FlatIndexParams()),
          FieldSchema(name: 'title', dataType: DataType.string),
        ],
      );

      collection = Collection.createAndOpen(
        '${dir.path}${Platform.pathSeparator}db',
        schema,
      );
      schema.destroy();
      schema = null;

      final docs = [
        Doc(id: 'nearest')
          ..setField('title', 'Nearest')
          ..setVector('embedding', Float32List.fromList([1, 0, 0, 0])),
        Doc(id: 'far')
          ..setField('title', 'Far')
          ..setVector('embedding', Float32List.fromList([0, 0, 0, 1])),
      ];

      final insertResult = collection.insert(docs);
      for (final doc in docs) {
        doc.destroy();
      }
      expect(insertResult.successCount, docs.length);
      expect(insertResult.errorCount, 0);

      collection.optimize();

      query = VectorQuery(
        fieldName: 'embedding',
        vector: Float32List.fromList([1, 0, 0, 0]),
        topk: 1,
        outputFields: ['title'],
      );
      final results = collection.query(query);

      expect(results, hasLength(1));
      expect(results.single.pk, 'nearest');
      expect(results.single.getString('title'), 'Nearest');
    } finally {
      query?.destroy();
      schema?.destroy();
      collection?.close();
      dir.deleteSync(recursive: true);
      Zvec.shutdown();
    }
  });
}
