import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zvec/zvec.dart';

Directory _createTempDir(String prefix) {
  final root = Directory('${Directory.current.parent.path}/tmp');
  root.createSync(recursive: true);
  return root.createTempSync('zvec_example_$prefix');
}

String _dbPath(Directory dir) => '${dir.path}/db';

void main() {
  setUpAll(() => Zvec.initialize());
  tearDownAll(() => Zvec.shutdown());

  test('uses packaged Jieba dictionaries for FTS queries', () {
    final dictDir = Zvec.defaultJiebaDictDir;
    expect(dictDir, isNotNull);
    expect(File('$dictDir/jieba.dict.utf8').existsSync(), isTrue);
    expect(File('$dictDir/hmm_model.utf8').existsSync(), isTrue);

    final tmpDir = _createTempDir('jieba_fts');
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

      final schema = CollectionSchema(name: 'example_jieba_fts');
      schema.addField(title);
      schema.addField(content);
      title.destroy();
      content.destroy();
      ftsParams.destroy();

      collection = Collection.createAndOpen(_dbPath(tmpDir), schema);
      schema.destroy();

      final docs = [
        Doc(id: 'pk_match')
          ..setField('title', 'match')
          ..setField('content', '中华人民共和国成立'),
        Doc(id: 'pk_miss')
          ..setField('title', 'miss')
          ..setField('content', '无关文档'),
      ];
      final insertResult = collection.insert(docs);
      for (final doc in docs) {
        doc.destroy();
      }
      expect(insertResult.isAllSuccess, isTrue, reason: '$insertResult');

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
      expect(ids, contains('pk_match'));
      expect(ids, isNot(contains('pk_miss')));
    } finally {
      try {
        collection?.close();
      } catch (_) {}
      if (tmpDir.existsSync()) {
        tmpDir.deleteSync(recursive: true);
      }
    }
  });
}
