// Run in separate processes with ZVEC_LIBRARY_PATH pointing first to the
// zvec-dart 0.5.2 engine and then to the 0.8.0 engine.
import 'dart:typed_data';

import 'package:zvec/zvec.dart';

void main(List<String> args) {
  if (args.length != 2 || !['create', 'verify'].contains(args.first)) {
    throw ArgumentError('Usage: collection_upgrade.dart create|verify <db>');
  }
  final create = args.first == 'create';
  if (Zvec.versionMajor != 0 ||
      Zvec.versionMinor != (create ? 5 : 8) ||
      (!create && Zvec.versionPatch != 0)) {
    throw StateError('Unexpected engine ${Zvec.version} for ${args.first}');
  }

  Zvec.initialize();
  try {
    if (create) {
      _create(args.last);
    } else {
      _verify(args.last);
    }
  } finally {
    Zvec.shutdown();
  }
}

void _create(String path) {
  final params = HnswIndexParams();
  final vector = VectorSchema('embedding', 4, indexParams: params);
  final title = FieldSchema(name: 'title', dataType: DataType.string);
  final schema = CollectionSchema(name: 'upgrade', fields: [vector, title]);
  final collection = Collection.createAndOpen(path, schema);
  final docs = [
    Doc(id: 'nearest')
      ..setField('title', 'original')
      ..setVector('embedding', Float32List.fromList([1, 0, 0, 0])),
    Doc(id: 'far')
      ..setField('title', 'other')
      ..setVector('embedding', Float32List.fromList([0, 0, 0, 1])),
  ];
  try {
    final result = collection.insert(docs);
    if (!result.isAllSuccess) throw StateError(result.toString());
    collection.optimize();
    collection.flush();
  } finally {
    for (final doc in docs) {
      doc.destroy();
    }
    collection.close();
    schema.destroy();
    title.destroy();
    vector.destroy();
    params.destroy();
  }
}

void _verify(String path) {
  final collection = Collection.open(path);
  final query = VectorQuery(
    fieldName: 'embedding',
    vector: Float32List.fromList([1, 0, 0, 0]),
    topk: 1,
  );
  try {
    final fetched = collection.fetch(['nearest']);
    final hits = collection.query(query);
    try {
      if (fetched.single.getString('title') != 'original' ||
          hits.single.pk != 'nearest') {
        throw StateError(
          'Stored field or nearest neighbor changed after upgrade',
        );
      }
    } finally {
      for (final doc in [...fetched, ...hits]) {
        doc.destroy();
      }
    }
  } finally {
    query.destroy();
    collection.close();
  }
}
