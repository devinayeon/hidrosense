import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/features/pest/domain/pest_summary.dart';
import 'package:hidrosense_mobile/features/pest/domain/yolo_decoder.dart';

YoloDetection det(int cls, double conf) =>
    YoloDetection(classId: cls, confidence: conf, x1: 0.1, y1: 0.1, x2: 0.2, y2: 0.2);

void main() {
  group('summarizeDetections', () {
    test('hitung per hama, urut indeks model, dengan keyakinan tertinggi', () {
      final r = summarizeDetections([det(2, 0.5), det(0, 0.9), det(2, 0.8), det(2, 0.6)]);
      expect(r.map((f) => f.kind), [PestKind.thrips, PestKind.aphids]);
      expect(r[0].count, 1);
      expect(r[1].count, 3);
      expect(r[1].maxConfidence, 0.8);
    });

    test('tanpa deteksi: daftar kosong', () => expect(summarizeDetections(const []), isEmpty));

    test('kelas di luar model ditolak keras', () {
      expect(() => summarizeDetections([det(3, 0.9)]), throwsRangeError);
    });
  });

  group('suggestSeverity (kuantil data latih per hama)', () {
    test('batas ambang tiap hama', () {
      for (final k in PestKind.values) {
        expect(suggestSeverity(k, 1), PestSeverity.ringan, reason: k.name);
        expect(suggestSeverity(k, k.sedangMin - 1), PestSeverity.ringan, reason: k.name);
        expect(suggestSeverity(k, k.sedangMin), PestSeverity.sedang, reason: k.name);
        expect(suggestSeverity(k, k.beratMin - 1), PestSeverity.sedang, reason: k.name);
        expect(suggestSeverity(k, k.beratMin), PestSeverity.berat, reason: k.name);
      }
    });

    test('foto kutu kebul biasa (median 19) tidak otomatis berat; 8 thrips sudah berat', () {
      expect(suggestSeverity(PestKind.whitefly, 19), PestSeverity.ringan);
      expect(suggestSeverity(PestKind.thrips, 8), PestSeverity.berat);
    });

    test('ambang dari data latih: sedang < berat untuk semua hama', () {
      for (final k in PestKind.values) {
        expect(k.sedangMin, lessThan(k.beratMin));
        expect(k.sedangMin, greaterThan(1));
      }
    });
  });

  group('kontrak dengan backend', () {
    test('kode hama dan tingkat sama dengan enum API', () {
      expect(PestKind.values.map((k) => k.apiCode), ['thrips', 'whitefly', 'aphids']);
      expect(PestSeverity.values.map((s) => s.apiCode), ['ringan', 'sedang', 'berat']);
      expect(PestKind.fromApiCode('whitefly'), PestKind.whitefly);
      expect(PestKind.fromApiCode('tikus'), isNull);
    });

    test('urutan kelas sama dengan labels.txt model', () {
      final labels = File('assets/ml/labels.txt').readAsLinesSync().where((l) => l.trim().isNotEmpty).toList();
      expect(labels, PestKind.values.map((k) => k.apiCode).toList());
    });
  });

  group('aset model yang ditanam', () {
    test('SHA-256 model sama dengan model_metadata.json dan artefak ml/', () {
      final meta = jsonDecode(File('assets/ml/model_metadata.json').readAsStringSync()) as Map<String, dynamic>;
      final bytes = File('assets/ml/yolo11n_lettuce_pests.tflite').readAsBytesSync();
      expect(sha256.convert(bytes).toString(), meta['sha256']);
      expect(meta['model_version'], 'yolo11n-fp16-cd388bda');
      final source = File('../../ml/artifacts/yolo11n_lettuce_pests.tflite');
      if (source.existsSync()) {
        expect(sha256.convert(source.readAsBytesSync()).toString(), meta['sha256']);
      }
    });

    test('kontrak tensor di metadata sama dengan konstanta dekoder', () {
      final meta = jsonDecode(File('assets/ml/model_metadata.json').readAsStringSync()) as Map<String, dynamic>;
      expect(meta['input_shape'], [1, kYoloInput, kYoloInput, 3]);
      expect(meta['output_shape'], [1, kYoloChannels, kYoloAnchors]);
      expect(meta['letterbox_pad_value'], kYoloPadValue.toInt());
      expect(meta['input_normalization'], '0_to_1');
    });
  });
}
