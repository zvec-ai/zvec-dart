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

import 'package:flutter_test/flutter_test.dart';
import 'package:zvec/zvec.dart';

/// Unit tests for Zvec Dart SDK type mappings and pure-Dart logic.
///
/// Note: Tests that require the native library (Collection, Doc FFI calls, etc.)
/// must be run as integration tests on a device or emulator with libzvec available.
void main() {
  group('DataType', () {
    test('fromValue returns correct enum', () {
      expect(DataType.fromValue(2), DataType.string);
      expect(DataType.fromValue(5), DataType.int64);
      expect(DataType.fromValue(23), DataType.vectorFp32);
      expect(DataType.fromValue(9999), DataType.undefined);
    });

    test('isDenseVector returns true for vector types', () {
      expect(DataType.vectorFp32.isDenseVector, isTrue);
      expect(DataType.vectorFp64.isDenseVector, isTrue);
      expect(DataType.vectorInt8.isDenseVector, isTrue);
      expect(DataType.string.isDenseVector, isFalse);
      expect(DataType.int64.isDenseVector, isFalse);
    });

    test('isSparseVector returns true for sparse types', () {
      expect(DataType.sparseVectorFp32.isSparseVector, isTrue);
      expect(DataType.sparseVectorFp16.isSparseVector, isTrue);
      expect(DataType.vectorFp32.isSparseVector, isFalse);
    });

    test('isVector returns true for all vector types', () {
      expect(DataType.vectorFp32.isVector, isTrue);
      expect(DataType.sparseVectorFp32.isVector, isTrue);
      expect(DataType.string.isVector, isFalse);
    });

    test('isArray returns true for array types', () {
      expect(DataType.arrayString.isArray, isTrue);
      expect(DataType.arrayInt64.isArray, isTrue);
      expect(DataType.arrayDouble.isArray, isTrue);
      expect(DataType.string.isArray, isFalse);
      expect(DataType.vectorFp32.isArray, isFalse);
    });
  });

  group('IndexType', () {
    test('fromValue returns correct enum', () {
      expect(IndexType.fromValue(1), IndexType.hnsw);
      expect(IndexType.fromValue(2), IndexType.ivf);
      expect(IndexType.fromValue(3), IndexType.flat);
      expect(IndexType.fromValue(10), IndexType.invert);
      expect(IndexType.fromValue(999), IndexType.undefined);
    });

    test('fts enum value is 11', () {
      expect(IndexType.fts.value, 11);
      expect(IndexType.fromValue(11), IndexType.fts);
    });
  });

  group('MetricType', () {
    test('fromValue returns correct enum', () {
      expect(MetricType.fromValue(1), MetricType.l2);
      expect(MetricType.fromValue(2), MetricType.ip);
      expect(MetricType.fromValue(3), MetricType.cosine);
      expect(MetricType.fromValue(999), MetricType.undefined);
    });
  });

  group('QuantizeType', () {
    test('fromValue returns correct enum', () {
      expect(QuantizeType.fromValue(1), QuantizeType.fp16);
      expect(QuantizeType.fromValue(2), QuantizeType.int8);
      expect(QuantizeType.fromValue(4), QuantizeType.rabitq);
      expect(QuantizeType.fromValue(999), QuantizeType.undefined);
    });
  });

  group('LogLevel', () {
    test('fromValue returns correct enum', () {
      expect(LogLevel.fromValue(0), LogLevel.debug);
      expect(LogLevel.fromValue(1), LogLevel.info);
      expect(LogLevel.fromValue(4), LogLevel.fatal);
      expect(LogLevel.fromValue(999), LogLevel.info); // fallback
    });
  });

  group('LogType', () {
    test('fromValue returns correct enum', () {
      expect(LogType.fromValue(0), LogType.console);
      expect(LogType.fromValue(1), LogType.file);
    });

    test('fromValue returns console for unknown values', () {
      expect(LogType.fromValue(999), LogType.console);
      expect(LogType.fromValue(-1), LogType.console);
    });
  });

  group('ZvecErrorCode', () {
    test('fromValue returns correct enum', () {
      expect(ZvecErrorCode.fromValue(0), ZvecErrorCode.ok);
      expect(ZvecErrorCode.fromValue(1), ZvecErrorCode.notFound);
      expect(ZvecErrorCode.fromValue(3), ZvecErrorCode.invalidArgument);
      expect(ZvecErrorCode.fromValue(10), ZvecErrorCode.unknown);
      expect(ZvecErrorCode.fromValue(999), ZvecErrorCode.unknown);
    });
  });

  group('ZvecException', () {
    test('toString with message', () {
      final e = ZvecException(ZvecErrorCode.notFound, 'collection not found');
      expect(e.toString(), 'ZvecException(notFound: collection not found)');
    });

    test('toString without message', () {
      final e = ZvecException(ZvecErrorCode.internalError);
      expect(e.toString(), 'ZvecException(internalError)');
    });
  });

  group('RerankStrategy', () {
    test('RrfRerank default rankConstant', () {
      const rrf = RrfRerank();
      expect(rrf.rankConstant, 60);
    });

    test('RrfRerank custom rankConstant', () {
      const rrf = RrfRerank(rankConstant: 100);
      expect(rrf.rankConstant, 100);
    });

    test('WeightedRerank stores weights', () {
      const wr = WeightedRerank(weights: [0.7, 0.3]);
      expect(wr.weights, [0.7, 0.3]);
      expect(wr.weights.length, 2);
    });

    test('RrfRerank is RerankStrategy', () {
      const rrf = RrfRerank();
      expect(rrf, isA<RerankStrategy>());
    });

    test('WeightedRerank is RerankStrategy', () {
      const wr = WeightedRerank(weights: [1.0]);
      expect(wr, isA<RerankStrategy>());
    });
  });

  group('WriteResult', () {
    test('properties', () {
      final r = WriteResult(8, 2);
      expect(r.successCount, 8);
      expect(r.errorCount, 2);
      expect(r.totalCount, 10);
      expect(r.isAllSuccess, isFalse);
    });

    test('isAllSuccess when no errors', () {
      final r = WriteResult(5, 0);
      expect(r.isAllSuccess, isTrue);
    });

    test('toString', () {
      final r = WriteResult(3, 1);
      expect(r.toString(), 'WriteResult(success=3, error=1)');
    });

    test('details expose per-document errors', () {
      const status = WriteStatus(
        index: 1,
        pk: 'pk_1',
        code: ZvecErrorCode.internalError,
        message: 'vector indexer not found',
      );
      final r = WriteResult(1, 1, const [
        WriteStatus(index: 0, code: ZvecErrorCode.ok),
        status,
      ]);

      expect(r.details.length, 2);
      expect(r.errors, [status]);
      expect(r.errorMessages, ['vector indexer not found']);
      expect(r.toString(), contains('vector indexer not found'));
    });
  });
}
