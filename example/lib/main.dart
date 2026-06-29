import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zvec/zvec.dart';

void main() {
  runApp(const ZvecDemoApp());
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
