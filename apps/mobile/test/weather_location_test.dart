import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/repositories/weather_location_repository.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/data/services/bmkg_weather_service.dart';
import 'package:hidrosense_mobile/data/services/device_locator.dart';
import 'package:hidrosense_mobile/data/services/local_kv_store.dart';
import 'package:hidrosense_mobile/models/weather_location.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/v2_sync_status.dart';
import 'package:hidrosense_mobile/viewmodels/weather_location_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/weather_viewmodel.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_cuaca_lokasi_sheet.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_beranda_page.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/bmkg_weather_fixture.dart';

// Permintaan pemilik (2026-11-23): lokasi cuaca hanya tiga pilihan tetap.
// Lokasi harus fleksibel mengikuti pengguna, dari backend sampai tampilan.

Future<LocalKvStore> _store() async => LocalKvStore(
  await databaseFactoryFfiNoIsolate.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      singleInstance: false,
      version: 1,
      onCreate: LocalKvStore.createSchema,
    ),
  ),
);

const _sabrang = WeatherLocation.partner;
const _gambir = WeatherLocation(
  adm4: '31.71.01.1001',
  village: 'Gambir',
  district: 'Gambir',
  regency: 'Kota Jakarta Pusat',
  province: 'Dki Jakarta',
);

ApiClient _api(Future<http.Response> Function(http.Request) handler) =>
    ApiClient(
      MockClient(handler),
      baseUri: Uri.parse('https://example.test/api/v1'),
    )..setTokens(accessToken: 'access', refreshToken: 'refresh');

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

class _FakeLocator implements DeviceLocator {
  _FakeLocator({this.failure});
  final DeviceLocationFailure? failure;

  @override
  Future<({double lat, double lon})> currentPosition() async {
    if (failure != null) throw DeviceLocationException(failure!);
    return (lat: -6.17, lon: 106.82);
  }
}

void main() {
  setUpAll(sqfliteFfiInit);

  group('WeatherLocation', () {
    test('menyimpan dan membaca kembali, menolak isi rusak', () {
      final copy = WeatherLocation.tryFromJson(
        jsonDecode(jsonEncode(_gambir.toJson())),
      );
      expect(copy, _gambir);
      expect(copy?.province, 'Dki Jakarta');
      expect(WeatherLocation.tryFromJson({'adm4': 'x'}), isNull);
      expect(
        WeatherLocation.tryFromJson({
          'adm4': '35092002',
          'village': 'a',
          'district': 'b',
          'regency': 'c',
        }),
        isNull,
      );
      expect(WeatherLocation.tryFromJson('bukan peta'), isNull);
    });
  });

  group('WeatherLocationRepository', () {
    test(
      'belum memilih: lokasi mitra; pilihan bertahan setelah aplikasi dibuka lagi',
      () async {
        final store = await _store();
        final api = _api((_) async => _json({}));
        addTearDown(api.close);
        final repo = WeatherLocationRepository(api, () async => store);
        expect(await repo.current(), WeatherLocation.partner);

        await repo.save(_gambir);
        final reopened = WeatherLocationRepository(api, () async => store);
        expect(await reopened.current(), _gambir);
      },
    );

    test('isi tersimpan yang rusak jatuh ke lokasi mitra', () async {
      final store = await _store();
      await store.set('device', 'weather_location', '{rusak');
      expect(
        await WeatherLocationRepository.savedOrDefault(() async => store),
        WeatherLocation.partner,
      );
    });

    test('daftar wilayah dan posisi GPS dibaca dari backend', () async {
      final seen = <Uri>[];
      final api = _api((request) async {
        seen.add(request.url);
        if (request.url.path.endsWith('/weather/regions')) {
          return _json({
            'data': [
              {'id': '3509122002', 'name': 'Sabrang', 'adm4': '35.09.12.2002'},
            ],
          });
        }
        return _json({
          'data': {
            'adm4': '35.09.12.2002',
            'province': 'Jawa Timur',
            'regency': 'Kabupaten Jember',
            'district': 'Ambulu',
            'village': 'Sabrang',
            'approximate': true,
          },
        });
      });
      addTearDown(api.close);
      final repo = WeatherLocationRepository(api, () async => null);

      final rows = await repo.regions(
        WeatherRegionLevel.village,
        parent: '350912',
      );
      expect(rows.single.adm4, '35.09.12.2002');
      expect(seen.single.queryParameters, {
        'level': 'village',
        'parent': '350912',
      });

      final located = await repo.locate(-8.3667, 113.6101);
      expect(located.village, 'Sabrang');
      expect(located.approximate, isTrue);
      expect(seen.last.queryParameters['lat'], '-8.366700');
    });
  });

  group('BmkgWeatherService', () {
    Map<String, dynamic> gambirBody() {
      final body = bmkgWeatherFixture();
      Map<String, dynamic> swap(Map<String, dynamic> lokasi) => {
        ...lokasi,
        'adm4': '31.71.01.1001',
        'desa': 'Gambir',
        'kecamatan': 'Gambir',
        'kotkab': 'Jakarta Pusat',
      };
      body['lokasi'] = swap(body['lokasi'] as Map<String, dynamic>);
      final root = (body['data'] as List).first as Map<String, dynamic>;
      root['lokasi'] = swap(root['lokasi'] as Map<String, dynamic>);
      return body;
    }

    test(
      'meminta desa yang dipilih dan tidak lagi berlabel kebun mitra',
      () async {
        Uri? requested;
        final service = BmkgWeatherService(
          adm4: '31.71.01.1001',
          client: MockClient((request) async {
            requested = request.url;
            return http.Response(jsonEncode(gambirBody()), 200);
          }),
        );
        addTearDown(service.close);
        final data = await service.fetchWeather(
          fetchedAt: DateTime.utc(2026, 10, 25, 1, 30),
        );
        expect(requested?.queryParameters['adm4'], '31.71.01.1001');
        expect(data.kota, 'Gambir, Gambir, Jakarta Pusat');
        expect(data.lokasi, 'Gambir');
        expect(data.lokasi, isNot('KEBUN HIDRO SELADA'));
      },
    );

    test('BMKG tidak terjangkau: prakiraan diambil lewat backend', () async {
      var fallbackFor = '';
      final service = BmkgWeatherService(
        adm4: '35.09.12.2002',
        client: MockClient((_) async => throw http.ClientException('putus')),
        serverFallback: (adm4) async {
          fallbackFor = adm4;
          return bmkgWeatherFixture();
        },
      );
      addTearDown(service.close);
      final data = await service.fetchWeather(
        fetchedAt: DateTime.utc(2026, 10, 25, 1, 30),
      );
      expect(fallbackFor, '35.09.12.2002');
      expect(data.suhu, 29);
    });

    test(
      'BMKG dan backend sama-sama gagal: galat BMKG yang dilaporkan',
      () async {
        final service = BmkgWeatherService(
          adm4: '35.09.12.2002',
          client: MockClient((_) async => http.Response('x', 503)),
          serverFallback: (_) async => throw const FormatException('x'),
        );
        addTearDown(service.close);
        await expectLater(
          service.fetchWeather(),
          throwsA(
            isA<BmkgWeatherException>().having(
              (e) => e.message,
              'message',
              contains('503'),
            ),
          ),
        );
      },
    );

    test('cadangan backend untuk desa lain ditolak', () async {
      final service = BmkgWeatherService(
        adm4: '35.09.12.2002',
        client: MockClient((_) async => http.Response('x', 503)),
        serverFallback: (_) async => gambirBody(),
      );
      addTearDown(service.close);
      await expectLater(
        service.fetchWeather(),
        throwsA(isA<BmkgWeatherException>()),
      );
    });
  });

  group('weatherLocationProvider', () {
    test(
      'berganti lokasi mengganti desa yang diminta ke BMKG dan tersimpan',
      () async {
        final store = await _store();
        final api = _api((_) async => _json({}));
        addTearDown(api.close);
        final container = ProviderContainer(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            localKvStoreProvider.overrideWithValue(Future.value(store)),
          ],
        );
        addTearDown(container.dispose);

        expect(
          container.read(bmkgWeatherServiceProvider).adm4,
          WeatherLocation.partner.adm4,
        );
        await container.read(weatherLocationProvider.notifier).select(_gambir);
        expect(container.read(bmkgWeatherServiceProvider).adm4, _gambir.adm4);

        // Aplikasi dibuka lagi: pilihan terpasang sebelum layar pertama.
        final second = ProviderContainer(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            localKvStoreProvider.overrideWithValue(Future.value(store)),
          ],
        );
        addTearDown(second.dispose);
        await second.read(weatherLocationProvider.notifier).restore();
        expect(second.read(weatherLocationProvider), _gambir);
        expect(second.read(bmkgWeatherServiceProvider).adm4, _gambir.adm4);
      },
    );

    test(
      'lokasi perangkat: GPS lalu backend; GPS mati melempar alasannya',
      () async {
        final api = _api((request) async {
          expect(request.url.path, endsWith('/weather/locate'));
          return _json({
            'data': {
              'adm4': '31.71.01.1001',
              'province': 'Dki Jakarta',
              'regency': 'Kota Jakarta Pusat',
              'district': 'Gambir',
              'village': 'Gambir',
              'approximate': false,
            },
          });
        });
        addTearDown(api.close);
        final container = ProviderContainer(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            localKvStoreProvider.overrideWithValue(Future.value(null)),
          ],
        );
        addTearDown(container.dispose);
        final notifier = container.read(weatherLocationProvider.notifier);

        expect(await notifier.locateDevice(_FakeLocator()), _gambir);
        await expectLater(
          notifier.locateDevice(
            _FakeLocator(failure: DeviceLocationFailure.serviceOff),
          ),
          throwsA(isA<DeviceLocationException>()),
        );
      },
    );
  });

  group('V2CuacaLokasiSheet', () {
    final provinces = [
      const WeatherRegion(id: '35', name: 'Jawa Timur'),
      const WeatherRegion(id: '31', name: 'Dki Jakarta'),
    ];

    Future<WeatherLocation?> openSheet(
      WidgetTester tester, {
      DeviceLocator? locator,
      Future<List<WeatherRegion>> Function(WeatherRegionLevel, String?)? load,
    }) async {
      WeatherLocation? result;
      var closed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showModalBottomSheet<WeatherLocation>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => V2CuacaLokasiSheet(
                      current: _sabrang,
                      loadRegions:
                          load ??
                          (level, parent) async => switch (level) {
                            WeatherRegionLevel.province => provinces,
                            WeatherRegionLevel.regency => [
                              const WeatherRegion(
                                id: '3171',
                                name: 'Kota Jakarta Pusat',
                              ),
                            ],
                            WeatherRegionLevel.district => [
                              const WeatherRegion(id: '317101', name: 'Gambir'),
                            ],
                            WeatherRegionLevel.village => [
                              const WeatherRegion(
                                id: '3171011001',
                                name: 'Gambir',
                                adm4: '31.71.01.1001',
                              ),
                            ],
                          },
                      locateDevice: () async {
                        final fix = await (locator ?? _FakeLocator())
                            .currentPosition();
                        expect(fix.lat, isNotNull);
                        return _gambir;
                      },
                    ),
                  );
                  closed = true;
                },
                child: const Text('Buka'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Buka'));
      await tester.pumpAndSettle();
      // Ditandai selesai oleh pemanggil lewat [closed]; hasil dibaca lewat getter.
      addTearDown(() => closed);
      return Future.value(result);
    }

    testWidgets(
      'lebih dari tiga wilayah: daftar nyata, bukan Malang/Batu/Pasuruan',
      (tester) async {
        await openSheet(tester);
        expect(find.text('Jawa Timur'), findsOneWidget);
        expect(find.text('Dki Jakarta'), findsOneWidget);
        expect(find.text('Malang, Jawa Timur'), findsNothing);
        expect(find.text('Batu, Jawa Timur'), findsNothing);
        expect(find.text('Pasuruan, Jawa Timur'), findsNothing);
        expect(find.text('Gunakan lokasi saya'), findsOneWidget);
      },
    );

    testWidgets(
      'turun dari provinsi sampai desa memilih lokasi dengan kode adm4',
      (tester) async {
        await openSheet(tester);
        await tester.ensureVisible(find.text('Dki Jakarta'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Dki Jakarta'));
        await tester.pumpAndSettle();
        expect(find.text('Kota Jakarta Pusat'), findsOneWidget);
        await tester.ensureVisible(find.text('Kota Jakarta Pusat'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Kota Jakarta Pusat'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Gambir'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Gambir'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Gambir'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Gambir'));
        await tester.pumpAndSettle();
        expect(find.text('Pilih lokasi'), findsNothing); // sheet tertutup
      },
    );

    testWidgets('kolom cari menyaring daftar', (tester) async {
      await openSheet(tester);
      await tester.enterText(find.byType(TextField), 'jawa');
      await tester.pump();
      expect(find.text('Jawa Timur'), findsOneWidget);
      expect(find.text('Dki Jakarta'), findsNothing);
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.textContaining('Tidak ada'), findsOneWidget);
    });

    testWidgets('daftar gagal dimuat: pesan dan Coba lagi yang berfungsi', (
      tester,
    ) async {
      var calls = 0;
      await openSheet(
        tester,
        load: (level, parent) async {
          calls++;
          if (calls == 1) throw Exception('offline');
          return provinces;
        },
      );
      expect(find.textContaining('belum bisa dimuat'), findsOneWidget);
      await tester.ensureVisible(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.text('Jawa Timur'), findsOneWidget);
    });

    testWidgets('GPS mati: pesan jelas dan daftar manual tetap bisa dipakai', (
      tester,
    ) async {
      await openSheet(
        tester,
        locator: _FakeLocator(failure: DeviceLocationFailure.serviceOff),
      );
      await tester.ensureVisible(find.text('Gunakan lokasi saya'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gunakan lokasi saya'));
      await tester.pumpAndSettle();
      expect(find.textContaining('GPS mati'), findsOneWidget);
      expect(find.text('Jawa Timur'), findsOneWidget);
    });

    testWidgets('GPS berhasil menutup sheet dengan lokasi pengguna', (
      tester,
    ) async {
      await openSheet(tester);
      await tester.ensureVisible(find.text('Gunakan lokasi saya'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gunakan lokasi saya'));
      await tester.pumpAndSettle();
      expect(find.text('Pilih lokasi'), findsNothing);
    });
  });

  group('kartu cuaca Beranda', () {
    testWidgets(
      'membuka halaman Cuaca tersambung, bukan halaman contoh tiga lokasi',
      (tester) async {
        tester.view.physicalSize = const Size(390, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var opened = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: V2BerandaPage(
              weatherTitle: 'Cerah, 31°C',
              weatherSubtitle: 'Curah hujan 0 mm',
              onOpenWeather: () => opened++,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(find.text('Cerah, 31°C'));
        await tester.pumpAndSettle();
        expect(opened, 1);
        expect(find.text('Malang, Jawa Timur'), findsNothing);
      },
    );
  });
}
