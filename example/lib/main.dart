import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zvec/zvec.dart';

Future<void> main() async {
  if (const bool.fromEnvironment('ZVEC_RELEASE_SMOKE')) {
    await _runReleaseSmoke();
    return;
  }

  runApp(const ZvecDemoApp());
}

Future<void> _runReleaseSmoke() async {
  var initialized = false;
  final dir = Directory.systemTemp.createTempSync('zvec_release_app_');

  try {
    stdout.writeln('Starting zvec release smoke test');
    Zvec.initialize();
    initialized = true;

    _runReleaseVectorSmoke(dir);
    _runReleaseJiebaSmoke(dir);

    stdout.writeln('zvec release smoke test passed');
    exit(0);
  } catch (error, stackTrace) {
    stderr.writeln('zvec release smoke test failed: $error');
    stderr.writeln(stackTrace);
    exit(1);
  } finally {
    if (initialized) {
      Zvec.shutdown();
    }
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  }
}

String _smokeDbPath(Directory dir, String name) {
  return '${dir.path}${Platform.pathSeparator}$name';
}

void _checkSmoke(bool condition, String message) {
  if (!condition) {
    throw StateError(message);
  }
}

void _runReleaseVectorSmoke(Directory dir) {
  Collection? collection;
  CollectionSchema? schema;
  VectorQuery? query;

  try {
    schema = CollectionSchema(
      name: 'release_vector_smoke',
      fields: [
        VectorSchema('embedding', 4, indexParams: FlatIndexParams()),
        FieldSchema(name: 'title', dataType: DataType.string),
      ],
    );

    collection = Collection.createAndOpen(
      _smokeDbPath(dir, 'vector_db'),
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
    _checkSmoke(
      insertResult.successCount == docs.length && insertResult.errorCount == 0,
      'Vector insert failed: $insertResult',
    );

    collection.optimize();

    query = VectorQuery(
      fieldName: 'embedding',
      vector: Float32List.fromList([1, 0, 0, 0]),
      topk: 1,
      outputFields: ['title'],
    );
    final results = collection.query(query);

    _checkSmoke(results.length == 1, 'Expected one vector result');
    _checkSmoke(results.single.pk == 'nearest', 'Unexpected vector result');
    _checkSmoke(
      results.single.getString('title') == 'Nearest',
      'Unexpected vector result title',
    );
  } finally {
    query?.destroy();
    schema?.destroy();
    collection?.close();
  }
}

void _runReleaseJiebaSmoke(Directory dir) {
  final dictDir = Zvec.defaultJiebaDictDir;
  _checkSmoke(dictDir != null, 'Default Jieba dict dir was not registered');
  _checkSmoke(
    File('$dictDir${Platform.pathSeparator}jieba.dict.utf8').existsSync(),
    'Missing packaged jieba.dict.utf8',
  );
  _checkSmoke(
    File('$dictDir${Platform.pathSeparator}hmm_model.utf8').existsSync(),
    'Missing packaged hmm_model.utf8',
  );

  Collection? collection;
  CollectionSchema? schema;
  FieldSchema? title;
  FieldSchema? content;
  FtsIndexParams? ftsParams;
  FtsQuery? fts;
  VectorQuery? query;

  try {
    title = FieldSchema(
      name: 'title',
      dataType: DataType.string,
      nullable: false,
    );
    content = FieldSchema(
      name: 'content',
      dataType: DataType.string,
      nullable: false,
    );
    ftsParams = FtsIndexParams(tokenizerName: 'jieba', filters: ['lowercase']);
    content.setIndexParams(ftsParams);

    schema = CollectionSchema(name: 'release_jieba_smoke');
    schema.addField(title);
    schema.addField(content);
    title.destroy();
    title = null;
    content.destroy();
    content = null;
    ftsParams.destroy();
    ftsParams = null;

    collection = Collection.createAndOpen(
      _smokeDbPath(dir, 'jieba_db'),
      schema,
    );
    schema.destroy();
    schema = null;

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
    _checkSmoke(
      insertResult.isAllSuccess,
      'Jieba insert failed: $insertResult',
    );

    fts = FtsQuery(matchString: '中华');
    query = VectorQuery.fts(
      fieldName: 'content',
      fts: fts,
      topk: 10,
      outputFields: ['title', 'content'],
    );
    final results = collection.query(query);

    final ids = results.map((doc) => doc.pk).toSet();
    _checkSmoke(ids.contains('pk_match'), 'Jieba FTS did not match pk_match');
    _checkSmoke(!ids.contains('pk_miss'), 'Jieba FTS matched pk_miss');
  } finally {
    query?.destroy();
    fts?.destroy();
    schema?.destroy();
    title?.destroy();
    content?.destroy();
    ftsParams?.destroy();
    collection?.close();
  }
}

class ZvecDemoApp extends StatelessWidget {
  const ZvecDemoApp({super.key, this.autoRun = true});

  final bool autoRun;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zvec Demo',
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: DemoPage(autoRun: autoRun),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key, this.autoRun = true});

  final bool autoRun;

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  final List<String> _logs = [];
  bool _running = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoRun) {
      Future.delayed(const Duration(milliseconds: 500), _runDemo);
    }
  }

  void _log(String message) {
    setState(() => _logs.add(message));
  }

  Future<void> _runDemo() async {
    setState(() {
      _logs.clear();
      _running = true;
    });

    try {
      // 1. Initialize Zvec
      _log('Initializing Zvec...');
      Zvec.initialize();
      _log('Version: ${Zvec.version}');

      // 2. Create collection path
      final dir = await getApplicationDocumentsDirectory();
      final dbPath = '${dir.path}/zvec_demo';
      // Clean up previous run
      final dbDir = Directory(dbPath);
      if (dbDir.existsSync()) {
        dbDir.deleteSync(recursive: true);
      }

      // 3. Define schema: a 4-dim FP32 vector field + a string field.
      //    We create the collection WITHOUT an HNSW index first, insert data,
      //    then call optimize() which builds the index automatically.
      _log('Creating collection schema...');
      final schema = CollectionSchema(
        name: 'demo',
        fields: [
          VectorSchema('embedding', 4, indexParams: HnswIndexParams()),
          FieldSchema(name: 'title', dataType: DataType.string),
        ],
      );

      // 4. Create and open collection
      _log('Creating collection at: $dbPath');
      final collection = Collection.createAndOpen(dbPath, schema);

      // 5. Insert 10 documents with random vectors
      _log('Inserting 10 documents...');
      final rng = Random(42);
      final docs = <Doc>[];
      for (var i = 0; i < 10; i++) {
        final vec = Float32List.fromList(
          List.generate(4, (_) => rng.nextDouble()),
        );
        final doc = Doc(id: 'doc_$i')
          ..setField('title', 'Document #$i')
          ..setVector('embedding', vec);
        docs.add(doc);
      }
      collection.insert(docs);
      _log('Inserted ${docs.length} documents.');
      for (final doc in docs) {
        doc.destroy();
      }

      // 6. Optimize (build index)
      _log('Optimizing collection...');
      collection.optimize();

      // 7. Get stats
      final stats = collection.stats;
      _log(
        'Collection stats: ${stats.docCount} docs, '
        '${stats.indexCount} indexes',
      );
      stats.destroy();

      // 8. Vector search
      _log('Querying with a random vector...');
      final queryVec = Float32List.fromList(
        List.generate(4, (_) => rng.nextDouble()),
      );
      final query = VectorQuery(
        fieldName: 'embedding',
        vector: queryVec,
        topk: 5,
        outputFields: ['title'],
      );
      final results = collection.query(query);
      _log('Found ${results.length} results:');
      for (final doc in results) {
        final pk = doc.pk ?? '?';
        final title = doc.getString('title') ?? '?';
        final score = doc.score.toStringAsFixed(4);
        _log('  $pk: "$title" (score: $score)');
      }
      query.destroy();

      // 9. Fetch by primary key
      _log('Fetching doc_0 and doc_5...');
      final fetched = collection.fetch(['doc_0', 'doc_5']);
      for (final doc in fetched) {
        _log('  Fetched: ${doc.pk} - ${doc.getString('title')}');
      }

      // 10. Close collection
      collection.close();
      _log('Collection closed.');

      // 11. Shutdown
      Zvec.shutdown();
      _log('Zvec shutdown. Demo complete!');
    } catch (e, st) {
      _log('ERROR: $e');
      _log(st.toString().split('\n').take(5).join('\n'));
    } finally {
      setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zvec Demo')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _running ? null : _runDemo,
              child: Text(_running ? 'Running...' : 'Run Demo'),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    _logs[index],
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
