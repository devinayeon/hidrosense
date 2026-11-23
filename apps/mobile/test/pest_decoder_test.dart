import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/features/pest/domain/yolo_decoder.dart';
import 'package:image/image.dart' as img;

/// Paritas dengan ml/export_tflite.py (decode_yolov11_output) dan ml/evaluate.py
/// (_letterbox_bgr_to_rgb_float). Golden dibuat dari model TFLite asli di Python.
Map<String, dynamic> _golden() =>
    jsonDecode(File('test/fixtures/yolo_golden.json').readAsStringSync())
        as Map<String, dynamic>;

/// Tensor [7, 8400] berisi nol kecuali jangkar golden. Nol berada di bawah ambang,
/// jadi hasilnya sama dengan tensor penuh.
Float32List _tensorFrom(List<dynamic> anchors) {
  final out = Float32List(7 * kYoloAnchors);
  for (final row in anchors) {
    final values = row as List<dynamic>;
    final index = (values[0] as num).toInt();
    for (var ch = 0; ch < 7; ch++) {
      out[ch * kYoloAnchors + index] = (values[ch + 1] as num).toDouble();
    }
  }
  return out;
}

void main() {
  group('decodeYolov11Output', () {
    test('sama dengan decoder Python pada keluaran model asli', () {
      final cases = (_golden()['cases'] as List<dynamic>).cast<Map<String, dynamic>>();
      expect(cases, isNotEmpty);
      for (final c in cases) {
        final expected = (c['expected'] as List<dynamic>).cast<Map<String, dynamic>>();
        final got = decodeYolov11Output(_tensorFrom(c['anchors'] as List<dynamic>));
        expect(got.length, expected.length, reason: c['source'] as String);
        for (var i = 0; i < expected.length; i++) {
          expect(got[i].classId, expected[i]['class_id'], reason: 'kelas #$i ${c['source']}');
          expect(got[i].confidence, closeTo((expected[i]['confidence'] as num).toDouble(), 1e-4));
          final box = (expected[i]['box'] as List<dynamic>).map((e) => (e as num).toDouble()).toList();
          expect(got[i].x1, closeTo(box[0], 1e-4));
          expect(got[i].y1, closeTo(box[1], 1e-4));
          expect(got[i].x2, closeTo(box[2], 1e-4));
          expect(got[i].y2, closeTo(box[3], 1e-4));
        }
      }
    });

    test('golden mencakup ketiga kelas', () {
      final classes = <int>{};
      for (final c in (_golden()['cases'] as List<dynamic>).cast<Map<String, dynamic>>()) {
        for (final d in (c['expected'] as List<dynamic>).cast<Map<String, dynamic>>()) {
          classes.add(d['class_id'] as int);
        }
      }
      expect(classes, {0, 1, 2});
    });

    Float32List one(double cx, double cy, double w, double h, List<double> s) {
      final out = Float32List(7 * kYoloAnchors);
      final v = [cx, cy, w, h, ...s];
      for (var ch = 0; ch < 7; ch++) {
        out[ch * kYoloAnchors] = v[ch];
      }
      return out;
    }

    test('tensor kosong atau semua di bawah ambang: tidak ada deteksi', () {
      expect(decodeYolov11Output(Float32List(7 * kYoloAnchors)), isEmpty);
      expect(decodeYolov11Output(Float32List(0)), isEmpty);
    });

    test('skor tepat di ambang lolos, sedikit di bawahnya tidak', () {
      // 0.5 tepat di float32; 0.35 tidak (menjadi 0.34999999…), sama dengan perilaku Python.
      expect(decodeYolov11Output(one(0.5, 0.5, 0.2, 0.2, [0.5, 0, 0]), confThreshold: 0.5), hasLength(1));
      expect(decodeYolov11Output(one(0.5, 0.5, 0.2, 0.2, [0.4999, 0, 0]), confThreshold: 0.5), isEmpty);
    });

    test('nilai NaN atau tak hingga dilewati, bukan membuat hasil rusak', () {
      final t = one(0.5, 0.5, 0.2, 0.2, [0.9, 0, 0]);
      t[kYoloAnchors * 4] = double.nan;
      expect(decodeYolov11Output(t), isEmpty);
      final u = one(0.5, 0.5, 0.2, 0.2, [0.9, 0, 0]);
      u[0] = double.infinity;
      expect(decodeYolov11Output(u), isEmpty);
    });

    test('koordinat piksel (>1.5) dinormalkan dengan ukuran gambar', () {
      final d = decodeYolov11Output(one(320, 320, 64, 64, [0.9, 0, 0]));
      expect(d, hasLength(1));
      expect(d.single.x1, closeTo(0.45, 1e-6));
      expect(d.single.x2, closeTo(0.55, 1e-6));
    });

    test('NMS: kelas sama yang tumpang tindih disaring, kelas berbeda dipertahankan', () {
      final out = Float32List(7 * kYoloAnchors);
      void put(int i, double cx, double cy, List<double> s) {
        final v = [cx, cy, 0.2, 0.2, ...s];
        for (var ch = 0; ch < 7; ch++) {
          out[ch * kYoloAnchors + i] = v[ch];
        }
      }

      put(0, 0.5, 0.5, [0.9, 0, 0]);
      put(1, 0.51, 0.5, [0.8, 0, 0]);
      put(2, 0.5, 0.5, [0, 0.7, 0]);
      final d = decodeYolov11Output(out);
      expect(d.map((e) => e.classId).toList(), [0, 1]);
    });

    test('kotak berukuran nol dibuang', () {
      expect(decodeYolov11Output(one(0.5, 0.5, 0, 0, [0.9, 0, 0])), isEmpty);
    });
  });

  group('computeLetterbox (setara _letterbox_bgr_to_rgb_float)', () {
    // (lebar, tinggi) asal → (new_w, new_h, left, top), dihitung dari fungsi Python.
    const table = {
      (800, 600): (640, 480, 0, 80),
      (300, 500): (384, 640, 128, 0),
      (641, 640): (640, 639, 0, 0),
      (1, 1000): (1, 640, 319, 0),
      (4000, 3000): (640, 480, 0, 80),
      (640, 640): (640, 640, 0, 0),
    };
    table.forEach((src, want) {
      test('${src.$1}x${src.$2}', () {
        final l = computeLetterbox(src.$1, src.$2);
        expect((l.newWidth, l.newHeight, l.left, l.top), want);
      });
    });

    test('ukuran tidak valid ditolak', () {
      expect(() => computeLetterbox(0, 10), throwsArgumentError);
    });
  });

  group('letterboxToTensor', () {
    test('piksel sampel sama dengan Python (toleransi dekoder JPEG)', () {
      final cases = (_golden()['cases'] as List<dynamic>).cast<Map<String, dynamic>>();
      for (final c in cases) {
        final image = img.decodeImage(File('test/fixtures/${c['file']}').readAsBytesSync())!;
        final tensor = letterboxToTensor(image);
        expect(tensor.length, kYoloInput * kYoloInput * 3);
        var worst = 0;
        var total = 0;
        var n = 0;
        for (final s in (c['input_samples'] as List<dynamic>)) {
          final y = (s[0] as num).toInt();
          final x = (s[1] as num).toInt();
          final rgb = (s[2] as List<dynamic>).cast<int>();
          for (var ch = 0; ch < 3; ch++) {
            final got = (tensor[(y * kYoloInput + x) * 3 + ch] * 255).round();
            final diff = (got - rgb[ch]).abs();
            worst = diff > worst ? diff : worst;
            total += diff;
            n++;
          }
        }
        expect(worst, lessThanOrEqualTo(8), reason: '${c['source']} selisih terbesar');
        expect(total / n, lessThan(2.0), reason: '${c['source']} selisih rata-rata');
      }
    });

    test('foto lanskap: area pad bernilai 114/255, isi tidak ikut tergeser', () {
      final image = img.Image(width: 800, height: 600);
      img.fill(image, color: img.ColorRgb8(255, 0, 0));
      final t = letterboxToTensor(image);
      double at(int y, int x, int ch) => t[(y * kYoloInput + x) * 3 + ch];
      expect(at(10, 300, 0), closeTo(114 / 255, 1e-6), reason: 'pad atas');
      expect(at(630, 300, 2), closeTo(114 / 255, 1e-6), reason: 'pad bawah');
      expect(at(320, 300, 0), closeTo(1.0, 1e-6), reason: 'isi merah');
      expect(at(320, 300, 1), closeTo(0.0, 1e-6));
      expect(at(79, 300, 0), closeTo(114 / 255, 1e-6));
      expect(at(80, 300, 0), closeTo(1.0, 1e-6));
    });

    test('foto potret: pad kiri dan kanan', () {
      final image = img.Image(width: 300, height: 500);
      img.fill(image, color: img.ColorRgb8(0, 255, 0));
      final t = letterboxToTensor(image);
      double at(int y, int x, int ch) => t[(y * kYoloInput + x) * 3 + ch];
      expect(at(300, 100, 1), closeTo(114 / 255, 1e-6));
      expect(at(300, 127, 1), closeTo(114 / 255, 1e-6));
      expect(at(300, 128, 1), closeTo(1.0, 1e-6));
      expect(at(300, 511, 1), closeTo(1.0, 1e-6));
      expect(at(300, 512, 1), closeTo(114 / 255, 1e-6));
    });
  });

  group('unletterbox', () {
    test('kotak pada foto lanskap kembali ke koordinat foto asli', () {
      final l = computeLetterbox(800, 600);
      final box = l.toOriginal(const YoloDetection(classId: 0, confidence: 0.9, x1: 0.0, y1: 0.125, x2: 1.0, y2: 0.875));
      expect(box.left, closeTo(0, 1e-6));
      expect(box.top, closeTo(0, 1e-6));
      expect(box.right, closeTo(800, 1e-6));
      expect(box.bottom, closeTo(600, 1e-6));
    });

    test('kotak yang jatuh di area pad dijepit ke dalam foto', () {
      final l = computeLetterbox(800, 600);
      final box = l.toOriginal(const YoloDetection(classId: 0, confidence: 0.9, x1: 0.0, y1: 0.0, x2: 1.0, y2: 1.0));
      expect(box.top, 0);
      expect(box.bottom, 600);
    });
  });
}
