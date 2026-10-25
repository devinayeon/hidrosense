import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/core/weather_rules.dart';

void main() {
  test('stable weather gets a routine action and positive summary', () {
    final result = evaluateWeatherRules(
      maxTemperature: 28,
      maxHumidity: 70,
      totalRainfallMm: 0,
      maxWindSpeed: 5,
      weatherDescriptions: const ['Cerah Berawan'],
    );

    expect(result.summary, contains('stabil'));
    expect(result.actions, hasLength(1));
    expect(result.actions.single.judul, 'Lanjutkan Perawatan Rutin');
    expect(result.actions.single.isPenting, isFalse);
  });

  test('extreme weather rules produce important actions', () {
    final result = evaluateWeatherRules(
      maxTemperature: 33,
      maxHumidity: 90,
      totalRainfallMm: 1.6,
      maxWindSpeed: 25,
      weatherDescriptions: const ['Hujan Ringan'],
    );

    expect(
      result.actions.where((action) => action.isPenting).map((a) => a.judul),
      containsAll([
        'Atur Debit Nutrisi Meja NFT',
        'Lindungi Instalasi & Sesuaikan Nutrisi',
        'Waspadai Jamur Daun',
      ]),
    );
    expect(result.summary, contains('Utamakan tindakan berlabel Penting'));
  });
}
