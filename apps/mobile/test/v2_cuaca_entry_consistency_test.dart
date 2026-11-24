// Regresi BUG-26: pintu masuk Cuaca dari Beranda dulu membuka halaman contoh
// desain (prakiraan 16/17/18 Nov dan lokasi contoh) sehingga berbeda dari pintu
// masuk lain (tab Rawat, detail siklus) yang memakai halaman connected (BMKG
// nyata). Sekarang semua pintu masuk memakai halaman connected yang sama, dan
// label "Hari Ini" memakai jam yang bisa disuntik, bukan `DateTime.now()`.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/data/services/bmkg_weather_service.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/weather_viewmodel.dart';
import 'package:hidrosense_mobile/views/pages/app_gate.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_rawat_data.dart';
import 'package:hidrosense_mobile/views/v2/connected/v2_cuaca_connected.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_beranda_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_rawat_list_page.dart';
import 'package:hidrosense_mobile/views/v2/theme/v2_tokens.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_checklist.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/bmkg_weather_fixture.dart';

const _user = SessionUser(
  id: '1',
  name: 'Mitra',
  username: 'mitra',
  role: 'petani',
  permissions: [
    'inventaris:read',
    'penyemaian:read',
    'budidaya:read',
    'cuaca:read',
  ],
);

/// "Hari ini" tetap: 24 Nov 2026 WIB (08.30).
final _today = DateTime.utc(2026, 11, 24, 1, 30);

String _ymd(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

/// Fixture BMKG dengan tanggal contoh digeser ke sekitar [day].
Map<String, dynamic> _fixtureOn(DateTime day) {
  final shifted = jsonEncode(bmkgWeatherFixture())
      .replaceAll('2026-10-25', _ymd(day))
      .replaceAll('2026-10-26', _ymd(day.add(const Duration(days: 1))));
  return jsonDecode(shifted) as Map<String, dynamic>;
}

/// Override bersama: sesi petani, layanan cuaca palsu, dan jam tetap.
List<Override> _overrides({DateTime? now}) {
  final api = ApiClient(
    MockClient((_) async => http.Response(jsonEncode({'data': {}}), 200)),
    baseUri: Uri.parse('https://example.test/api/v1'),
  );
  addTearDown(api.close);
  final service = BmkgWeatherService(
    client: MockClient(
      (_) async => http.Response(
        jsonEncode(_fixtureOn(DateTime(2026, 11, 24))),
        200,
      ),
    ),
  );
  addTearDown(service.close);
  return [
    apiClientProvider.overrideWithValue(api),
    sessionProvider.overrideWith(
      (_) => SessionViewModel(api, initialState: const SessionState(user: _user)),
    ),
    bmkgWeatherServiceProvider.overrideWithValue(service),
    weatherClockProvider.overrideWithValue(() => now ?? _today),
  ];
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(480, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(),
      child: MaterialApp(theme: V2Theme.light, home: child),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('kartu cuaca Beranda memakai pintu masuk yang disuntik', (
    tester,
  ) async {
    var dibuka = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: V2BerandaPage(onOpenWeather: () => dibuka++),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(V2WeatherCard));
    await tester.tap(find.byType(V2WeatherCard));
    await tester.pumpAndSettle();

    // Dulu kartu ini selalu membuka halaman contoh desain; sekarang ia harus
    // memakai pintu masuk nyata yang sama dengan hero/detail siklus.
    expect(dibuka, 1);
  });

  testWidgets(
    'pintu Cuaca dari Beranda membuka halaman connected dengan tanggal hari ini',
    (tester) async {
      await _pump(tester, const AppGate());

      await tester.ensureVisible(find.byType(V2WeatherCard));
      await tester.tap(find.byType(V2WeatherCard));
      await tester.pumpAndSettle();

      expect(find.byType(V2CuacaConnectedPage), findsOneWidget);
      expect(find.textContaining('Sabrang, Ambulu, Jember'), findsWidgets);

      // Tab prakiraan harus mulai dari hari ini (bukan 16 Nov contoh desain).
      await tester.tap(find.text('Prakiraan'));
      await tester.pumpAndSettle();
      expect(find.text('Hari Ini • 24 Nov 2026'), findsOneWidget);
      expect(find.text('Besok • 25 Nov 2026'), findsOneWidget);
      expect(find.textContaining('16 Nov'), findsNothing);
    },
  );

  testWidgets('pintu Cuaca dari tab Rawat memakai callback connected yang sama', (
    tester,
  ) async {
    var dibuka = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: V2Theme.light,
        home: Scaffold(
          body: V2RawatTabView(
            riwayat: [designRawatSelesai12],
            onOpenRotasi: () {},
            onOpenCuaca: () => dibuka++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Cuaca dan saran'));
    await tester.tap(find.text('Cuaca dan saran'));
    await tester.pumpAndSettle();

    expect(dibuka, 1);
  });
}
