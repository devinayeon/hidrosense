import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/core/fuzzy_weather.dart';
import 'package:hidrosense_mobile/core/weather_rules.dart';
import 'package:hidrosense_mobile/models/weather_model.dart';

FuzzyWeather f({
  int t = 28,
  int h = 70,
  double rain = 0,
  int wind = 5,
  bool rainText = false,
}) => fuzzifyWeather(
  maxTemperature: t,
  maxHumidity: h,
  totalRainfallMm: rain,
  maxWindSpeed: wind,
  hasRainText: rainText,
);

void main() {
  group('fungsi keanggotaan', () {
    test('ramp: 0 di bawah a, 1 di atas b, linear di antaranya', () {
      expect(ramp(10, 10, 20), 0);
      expect(ramp(15, 10, 20), 0.5);
      expect(ramp(25, 10, 20), 1);
      expect(ramp(5, 10, 20), 0);
    });

    test('trapezoid: naik, datar, turun, di luar = 0', () {
      expect(trapezoid(0, 1, 2, 3, 4), 0);
      expect(trapezoid(1.5, 1, 2, 3, 4), 0.5);
      expect(trapezoid(2.5, 1, 2, 3, 4), 1);
      expect(trapezoid(3.5, 1, 2, 3, 4), 0.5);
      expect(trapezoid(5, 1, 2, 3, 4), 0);
    });

    test('semua derajat selalu dalam 0..1 untuk masukan ekstrem', () {
      for (final t in [-50, 0, 33, 80]) {
        for (final h in [0, 85, 100, 500]) {
          final r = f(t: t, h: h, rain: 9999, wind: 400);
          for (final v in [r.hot, r.warm, r.humid, r.rain, r.windy, r.pestPressure]) {
            expect(v, inInclusiveRange(0.0, 1.0));
          }
        }
      }
    });
  });

  group('titik 0,5 sama dengan ambang lama', () {
    test('suhu: 32 tepat di 0,5, di atasnya panas', () {
      expect(f(t: 32).hot, 0.5);
      expect(f(t: 33).hot, greaterThan(0.5));
    });
    test('kelembapan 85 tepat di 0,5', () => expect(f(h: 85).humid, 0.5));
    test('hujan 0,5 mm tepat di 0,5; teks "hujan" memberi 1', () {
      expect(f(rain: 0.5).rain, 0.5);
      expect(f(rainText: true).rain, 1.0);
    });
    test('angin 20 km/jam tepat di 0,5', () => expect(f(wind: 20).windy, 0.5));
  });

  group('tekanan hama (pola dummy: hangat dan kering)', () {
    test('suhu sejuk: rendah', () => expect(f(t: 26).pestPressure, 0));
    test('panas dan kering: tinggi', () => expect(f(t: 34).pestPressure, 1.0));
    test('panas tetapi hujan deras: ditekan', () => expect(f(t: 34, rain: 5).pestPressure, 0));
  });

  group('evaluateWeatherRules tetap berkontrak sama', () {
    test('cuaca stabil: satu tindakan rutin', () {
      final r = evaluateWeatherRules(
        maxTemperature: 28, maxHumidity: 70, totalRainfallMm: 0, maxWindSpeed: 5,
        weatherDescriptions: const ['Cerah'],
      );
      expect(r.actions.single.judul, 'Lanjutkan Perawatan Rutin');
    });

    test('suhu persis 32: belum penting, hanya pantau', () {
      final r = evaluateWeatherRules(
        maxTemperature: 32, maxHumidity: 70, totalRainfallMm: 0, maxWindSpeed: 5,
        weatherDescriptions: const [],
      );
      expect(r.actions.where((a) => a.isPenting), isEmpty);
      expect(r.actions.map((a) => a.judul), contains('Pantau Suhu Larutan'));
    });

    test('panas dan kering menambah anjuran pantau hama, bukan menjadi wajib', () {
      final r = evaluateWeatherRules(
        maxTemperature: 34, maxHumidity: 60, totalRainfallMm: 0, maxWindSpeed: 5,
        weatherDescriptions: const ['Cerah'],
      );
      final pest = r.actions.where((a) => a.judul == 'Tingkatkan Pemantauan Hama');
      expect(pest, hasLength(1));
      expect(pest.single.isPenting, isFalse);
    });

    test('hujan menghapus anjuran pantau hama dari tekanan cuaca', () {
      final r = evaluateWeatherRules(
        maxTemperature: 34, maxHumidity: 60, totalRainfallMm: 5, maxWindSpeed: 5,
        weatherDescriptions: const ['Hujan'],
      );
      expect(r.actions.map((a) => a.judul), isNot(contains('Tingkatkan Pemantauan Hama')));
    });
  });

  group('inferensi fuzzy bertingkat (bukan ambang tajam)', () {
    List<TindakanRekomendasi> act({int t = 27, int h = 60, double rain = 0, int wind = 5, List<String> d = const []}) =>
        evaluateWeatherRules(maxTemperature: t, maxHumidity: h, totalRainfallMm: rain, maxWindSpeed: wind, weatherDescriptions: d).actions;

    test('kelembapan 86%: waspada jamur tetapi belum penting; 92%: penting', () {
      final mild = act(h: 86).singleWhere((a) => a.judul == 'Waspadai Jamur Daun');
      expect(mild.isPenting, isFalse);
      expect(mild.derajat, closeTo(0.55, 1e-9));
      final severe = act(h: 92).singleWhere((a) => a.judul == 'Waspadai Jamur Daun');
      expect(severe.isPenting, isTrue);
    });

    test('aturan majemuk: cukup lembap (80%) DAN hujan memicu waspada jamur', () {
      final withRain = act(h: 80, d: const ['Hujan Ringan']);
      expect(withRain.map((a) => a.judul), contains('Waspadai Jamur Daun'));
      final dry = act(h: 80);
      expect(dry.map((a) => a.judul), isNot(contains('Waspadai Jamur Daun')));
    });

    test('tindakan diurutkan menurut derajat, alasan menyebut derajatnya', () {
      final list = act(t: 33, h: 86, wind: 25);
      final degrees = list.map((a) => a.derajat!).toList();
      expect(degrees, [...degrees]..sort((a, b) => b.compareTo(a)));
      expect(list.first.alasan, contains('Derajat risiko'));
    });
  });
}
