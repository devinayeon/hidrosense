import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/services/bmkg_weather_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/bmkg_weather_fixture.dart';

void main() {
  test('requests partner adm4 and maps BMKG response to app data', () async {
    Uri? requested;
    final service = BmkgWeatherService(
      adm4: '35.09.12.2002',
      client: MockClient((request) async {
        requested = request.url;
        return http.Response(
          jsonEncode(bmkgWeatherFixture()),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(service.close);

    final data = await service.fetchWeather(
      fetchedAt: DateTime.utc(2026, 10, 25, 1, 30),
    );

    expect(requested?.host, 'api.bmkg.go.id');
    expect(requested?.queryParameters['adm4'], '35.09.12.2002');
    expect(data.kota, 'Sabrang, Ambulu, Jember');
    expect(data.sumber, contains('BMKG'));
    expect(data.suhu, 29);
    expect(data.kelembapan, 66);
    expect(data.curahHujan, '1.6 mm');
    expect(data.kecepatanAngin, 14);
    expect(data.arahAngin, 'Dari arah Tenggara');
    expect(data.lastUpdated, '25 Okt 2026 • 08:30 WIB');
    expect(data.prakiraanHarian, hasLength(2));
    expect(data.prakiraanHarian.first.waktu, 'Hari Ini • 25 Okt 2026');
    expect(data.prakiraanHarian.first.status, 'Hujan Ringan');
    expect(data.prakiraanHarian.first.suhu, 33);
    expect(
      data.prakiraanHarian.first.rekomendasiList.map((item) => item.judul),
      containsAll([
        'Atur Debit Nutrisi Meja NFT',
        'Lindungi Instalasi & Sesuaikan Nutrisi',
        'Waspadai Jamur Daun',
      ]),
    );
  });

  test('rejects a response for a different adm4', () async {
    final fixture = bmkgWeatherFixture();
    fixture['lokasi'] = {
      ...fixture['lokasi'] as Map<String, dynamic>,
      'adm4': '31.71.01.1001',
    };
    final service = BmkgWeatherService(
      client: MockClient((_) async => http.Response(jsonEncode(fixture), 200)),
    );
    addTearDown(service.close);

    await expectLater(
      service.fetchWeather(fetchedAt: DateTime.utc(2026, 10, 25, 1, 30)),
      throwsA(isA<BmkgWeatherException>()),
    );
  });

  test('reports an unavailable BMKG service', () async {
    final service = BmkgWeatherService(
      client: MockClient((_) async => http.Response('unavailable', 503)),
    );
    addTearDown(service.close);

    await expectLater(
      service.fetchWeather(fetchedAt: DateTime.utc(2026, 10, 25, 1, 30)),
      throwsA(
        isA<BmkgWeatherException>().having(
          (error) => error.message,
          'message',
          contains('503'),
        ),
      ),
    );
  });

  test('rejects an incomplete forecast', () {
    final fixture = bmkgWeatherFixture();
    final root = (fixture['data'] as List).first as Map;
    final rows = root['cuaca'] as List;
    rows.clear();

    expect(
      () => parseBmkgWeather(
        fixture,
        fetchedAt: DateTime.utc(2026, 10, 25, 1, 30),
      ),
      throwsA(isA<BmkgWeatherException>()),
    );
  });
}
