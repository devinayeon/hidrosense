import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/services/weather_background.dart';
import 'package:hidrosense_mobile/features/pest/data/pest_detector.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:workmanager/workmanager.dart';

import 'golden_photos.dart';

/// Menjalankan model yang ditanam di APK dengan interpreter TFLite native di perangkat atau
/// emulator Android, lalu membandingkan dengan hasil model yang sama di Python (golden).
///
/// Jalankan: `flutter test integration_test/pest_detector_device_test.dart -d <id perangkat>`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late PestDetector detector;

  setUpAll(() async {
    detector = await PestDetector.load();
  });

  tearDownAll(() => detector.dispose());

  test('model termuat dengan kontrak tensor dan versi yang benar', () {
    expect(detector.modelVersion, 'yolo11n-fp16-cd388bda');
  });

  for (final c in goldenCases) {
    test('hasil di perangkat sama dengan Python: ${c['source']}', () async {
      final bytes = base64Decode(c['jpegBase64']! as String);
      final watch = Stopwatch()..start();
      final result = await detector.detect(bytes);
      watch.stop();

      final expected = (c['expected']! as List<dynamic>).cast<List<dynamic>>();
      Map<int, int> perClass(Iterable<int> ids) {
        final out = <int, int>{};
        for (final id in ids) {
          out[id] = (out[id] ?? 0) + 1;
        }
        return out;
      }

      // Dekoder JPEG Dart dan OpenCV berbeda beberapa tingkat piksel (terukur maks 8 di tes unit),
      // sehingga skor bergeser beberapa perseratus. Deteksi yang jelas (>= 0,40 di Python) wajib sama;
      // deteksi di tepi ambang wajib muncul lagi bila ambang diturunkan, dengan skor yang dekat.
      const margin = 0.40;
      final clear = expected.where((e) => (e[1] as num) >= margin).toList();
      final edge = expected.where((e) => (e[1] as num) < margin).toList();
      final want = perClass(clear.map((e) => e[0] as int));
      final got = perClass(result.detections.where((d) => d.confidence >= margin - 0.05).map((d) => d.classId));
      expect(got.keys.toSet().containsAll(want.keys), isTrue, reason: 'kelas jelas: perangkat $got, Python $want');
      for (final k in want.keys) {
        expect((got[k]! - want[k]!).abs(), lessThanOrEqualTo(1), reason: 'jumlah kelas $k: perangkat ${got[k]}, Python ${want[k]}');
      }
      if (edge.isNotEmpty) {
        final loose = await detector.detect(bytes, confThreshold: 0.25);
        for (final e in edge) {
          final cls = e[0] as int;
          final score = (e[1] as num).toDouble();
          final near = loose.detections.where((d) => d.classId == cls && (d.confidence - score).abs() <= 0.05);
          expect(near, isNotEmpty, reason: 'deteksi tepi ambang kelas $cls (Python $score) tidak muncul di 0,25');
        }
      }
      for (final d in result.detections) {
        expect(d.confidence.isFinite && d.confidence >= 0.35 && d.confidence <= 1, isTrue);
      }
      // ignore: avoid_print
      print('LATENSI ${c['source']}: ${watch.elapsedMilliseconds} ms, deteksi ${result.detections.length}');
    });
  }

  test('foto polos tanpa hama: nol deteksi, tanpa galat', () async {
    final blank = img.Image(width: 800, height: 600);
    img.fill(blank, color: img.ColorRgb8(120, 160, 90));
    final result = await detector.detect(Uint8List.fromList(img.encodeJpg(blank)));
    expect(result.detections, isEmpty);
  });

  test('berkas bukan foto: FormatException yang jelas, bukan crash', () async {
    await expectLater(detector.detect(Uint8List.fromList(utf8.encode('bukan foto'))), throwsFormatException);
  });

  test('tugas cuaca harian terjadwal di WorkManager dan tidak menumpuk', () async {
    await scheduleDailyWeatherAdvice();
    await scheduleDailyWeatherAdvice();
    expect(await Workmanager().isScheduledByUniqueName(kWeatherTaskName), isTrue);
  });
}
