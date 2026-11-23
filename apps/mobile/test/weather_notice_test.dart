import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/core/weather_notice.dart';
import 'package:hidrosense_mobile/core/weather_rules.dart';
import 'package:hidrosense_mobile/data/services/weather_notification_service.dart';
import 'package:hidrosense_mobile/models/weather_model.dart';
import 'package:hidrosense_mobile/viewmodels/weather_viewmodel.dart';

PrakiraanHarian day({int t = 27, int h = 60, double rain = 0, List<String> d = const []}) {
  final rules = evaluateWeatherRules(maxTemperature: t, maxHumidity: h, totalRainfallMm: rain, maxWindSpeed: 5, weatherDescriptions: d);
  return PrakiraanHarian(waktu: 'Hari Ini', status: 'Cerah', suhu: t, ringkasanSaran: rules.summary, rekomendasiList: rules.actions);
}

WeatherData weather(List<PrakiraanHarian> days) => WeatherData(
  lokasi: 'Sabrang', kota: 'Jember', sumber: 'BMKG', suhu: 30, statusSuhu: '', kelembapan: 60,
  statusKelembapan: '', curahHujan: '0 mm', estimasiHujan: '', kecepatanAngin: 5, arahAngin: '',
  prakiraanHarian: days, lastUpdated: '',
);

class FakeSink implements WeatherNoticeSink {
  final delivered = <WeatherNotice>[];
  @override
  Future<void> deliver(WeatherNotice notice) async => delivered.add(notice);
}

void main() {
  final today = DateTime(2026, 11, 23, 7);

  test('cuaca stabil: tidak ada notifikasi (perawatan rutin tidak layak mengganggu)', () {
    expect(buildWeatherNotice(day(), today), isNull);
  });

  test('panas dan lembap: judul menyebut jumlah penting, isi dua saran teratas, boleh diabaikan', () {
    final n = buildWeatherNotice(day(t: 34, h: 92, d: const ['Hujan Ringan']), today)!;
    expect(n.title, 'Saran cuaca hari ini: 3 penting');
    expect(n.body, contains(' · '));
    expect(n.body, contains('saran lain'));
    expect(n.body, endsWith('Keputusan tetap di tangan Anda.'));
  });

  test('id per tanggal: hari yang sama menimpa, hari berbeda tidak', () {
    final a = buildWeatherNotice(day(t: 34), today)!;
    final b = buildWeatherNotice(day(t: 34), DateTime(2026, 11, 23, 18))!;
    final c = buildWeatherNotice(day(t: 34), DateTime(2026, 11, 24))!;
    expect(a.id, 20261123);
    expect(b.id, a.id);
    expect(c.id, isNot(a.id));
  });

  test('saran hanya rutin (tanpa penting): judul tanpa hitungan', () {
    final n = buildWeatherNotice(day(t: 32), today)!;
    expect(n.title, 'Saran cuaca hari ini');
  });

  test('notifyTodayAdvice memakai prakiraan hari ini, bukan besok, dan diam bila kosong', () {
    final sink = FakeSink();
    notifyTodayAdvice(weather([day(), day(t: 34)]), sink, today);
    expect(sink.delivered, isEmpty, reason: 'hari ini stabil; besok panas tidak dikirim hari ini');
    notifyTodayAdvice(weather([day(t: 34)]), sink, today);
    expect(sink.delivered, hasLength(1));
    notifyTodayAdvice(weather(const []), sink, today);
    expect(sink.delivered, hasLength(1));
  });

  test('WeatherViewModel memanggil onLoaded hanya setelah berhasil memuat', () async {
    final loaded = <WeatherData>[];
    final ok = WeatherViewModel(loader: () async => weather([day(t: 34)]), onLoaded: loaded.add);
    await Future<void>.delayed(Duration.zero);
    expect(loaded, hasLength(1));
    final failing = WeatherViewModel(loader: () async => throw Exception('BMKG mati'), onLoaded: loaded.add);
    await Future<void>.delayed(Duration.zero);
    expect(loaded, hasLength(1));
    expect(failing.state.errorMessage, isNotNull);
    ok.dispose();
    failing.dispose();
  });
}
