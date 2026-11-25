import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/views/pages/app_gate.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_beranda_connected_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_login_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_onboarding_page.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_button.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'support/damage_fixture.dart';

// Permintaan pemilik (2026-11-23): layar pertama aplikasi harus tampilan v2,
// bukan login lama; versi pertama dihapus.
ProviderScope _app(ApiClient api) => ProviderScope(
  overrides: [
    apiClientProvider.overrideWithValue(api),
    sessionProvider.overrideWith(
      (_) => SessionViewModel(api, openStore: () async => null),
    ),
  ],
  child: const MaterialApp(home: AppGate()),
);

ApiClient _api({bool loginSucceeds = true}) => ApiClient(
  MockClient((request) async {
    if (request.url.path.endsWith('/auth/login')) {
      if (!loginSucceeds) {
        return reply({
          'error': {'code': 'INVALID_CREDENTIALS', 'message': 'Salah'},
        }, status: 401);
      }
      return reply({
        'data': {
          'access_token': 'access',
          'refresh_token': 'refresh',
          'user': {
            'id_user': '1',
            'nama': 'Mitra',
            'username': 'mitra',
            'role': 'petani',
            'permissions': <String>[],
          },
        },
      });
    }
    if (request.url.path.endsWith('/auth/logout')) return reply({'data': {}});
    return http.Response('{"data":[],"meta":{}}', 200);
  }),
  baseUri: Uri.parse('https://example.test/api/v1'),
);

Future<void> _signIn(WidgetTester tester, {String password = 'secret'}) async {
  await tester.pumpAndSettle(const Duration(seconds: 3));
  await tester.tap(find.text('Lewati'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).at(0), 'mitra');
  await tester.enterText(find.byType(TextField).at(1), password);
  await tester.tap(find.widgetWithText(V2Button, 'Masuk'));
  await tester.pumpAndSettle();
}

void main() {
  late Directory dbDir;
  setUpAll(() async {
    // Beranda membuka antrean dan cache lokal; arahkan ke folder sementara.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    dbDir = await Directory.systemTemp.createTemp('first_screen_test_');
    await databaseFactory.setDatabasesPath(dbDir.path);
  });
  tearDownAll(() async {
    if (dbDir.existsSync()) await dbDir.delete(recursive: true);
  });

  testWidgets('layar pertama tanpa sesi adalah onboarding v2, bukan login lama', (
    tester,
  ) async {
    final api = _api();
    addTearDown(api.close);
    await tester.pumpWidget(_app(api));

    expect(find.byType(V2OnboardingPage), findsOneWidget);
    expect(find.text('Coba tampilan v2'), findsNothing);
    expect(find.text('Selamat datang\nkembali.'), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('login v2 sungguhan memasang sesi dan membuka beranda v2', (
    tester,
  ) async {
    final api = _api();
    addTearDown(api.close);
    await tester.pumpWidget(_app(api));
    await _signIn(tester);

    expect(find.byType(V2BerandaConnectedPage), findsOneWidget);
    expect(find.byType(V2OnboardingPage), findsNothing);
  });

  testWidgets('keluar akun kembali ke onboarding v2', (tester) async {
    final api = _api();
    addTearDown(api.close);
    await tester.pumpWidget(_app(api));
    await _signIn(tester);
    expect(find.byType(V2BerandaConnectedPage), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppGate)),
    );
    await container.read(sessionProvider.notifier).logout();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.byType(V2OnboardingPage), findsOneWidget);
    expect(find.byType(V2BerandaConnectedPage), findsNothing);
  });

  testWidgets('password salah tetap di halaman login v2 dengan pesan galat', (
    tester,
  ) async {
    final api = _api(loginSucceeds: false);
    addTearDown(api.close);
    await tester.pumpWidget(_app(api));
    await _signIn(tester, password: 'salah');

    expect(find.byType(V2LoginPage), findsOneWidget);
    expect(find.text('Username atau password salah'), findsOneWidget);
  });
}
