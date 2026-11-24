// Regresi BUG-19: saat sesi dipulihkan (aplikasi dibuka ulang setelah ditutup),
// aplikasi dulu mendarat di beranda v1 (MainPage) karena mode v2 tidak tersimpan.
// Sekarang jalur masuk v1 dinonaktifkan (D-15): begitu ada sesi, beranda v2 dipakai.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/views/pages/app_gate.dart';
import 'package:hidrosense_mobile/views/pages/main_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_beranda_connected_page.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _user = SessionUser(
  id: '1',
  name: 'Mitra',
  username: 'mitra',
  role: 'petani',
  permissions: ['inventaris:read', 'penyemaian:read', 'budidaya:read'],
);

void main() {
  testWidgets('sesi dipulihkan membuka beranda v2, bukan v1', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = ApiClient(
      MockClient((_) async => http.Response(jsonEncode({'data': {}}), 200)),
      baseUri: Uri.parse('https://example.test/api/v1'),
    );
    addTearDown(api.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          sessionProvider.overrideWith(
            (ref) => SessionViewModel(
              api,
              initialState: const SessionState(user: _user),
            ),
          ),
        ],
        child: const MaterialApp(home: AppGate()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(V2BerandaConnectedPage), findsOneWidget);
    expect(find.byType(MainPage), findsNothing);
    expect(find.textContaining('Halo, Mitra'), findsOneWidget);
  });
}
