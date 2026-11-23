import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/services/weather_background.dart';

import 'weather_notice_test.dart' show FakeSink, day, weather;

void main() {
  final now = DateTime(2026, 11, 23, 6);

  test('tugas latar: cuaca panas mengirim satu notifikasi, selesai dengan true', () async {
    final sink = FakeSink();
    final ok = await runDailyWeatherTask(load: () async => weather([day(t: 34)]), sink: sink, now: now);
    expect(ok, isTrue);
    expect(sink.delivered, hasLength(1));
    expect(sink.delivered.single.id, 20261123);
  });

  test('cuaca stabil: tidak mengganggu pengguna', () async {
    final sink = FakeSink();
    expect(await runDailyWeatherTask(load: () async => weather([day()]), sink: sink, now: now), isTrue);
    expect(sink.delivered, isEmpty);
  });

  test('BMKG gagal: tidak ada notifikasi, tidak melempar, tidak memicu retry beruntun', () async {
    final sink = FakeSink();
    final ok = await runDailyWeatherTask(load: () async => throw Exception('BMKG mati'), sink: sink, now: now);
    expect(ok, isTrue);
    expect(sink.delivered, isEmpty);
  });
}
