import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/inventory_record.dart';
import 'package:hidrosense_mobile/data/repositories/inventory_repository.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/data/services/inventory_cache.dart';
import 'package:hidrosense_mobile/viewmodels/connected_inventory_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/views/pages/app_gate.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('login menampilkan saldo; logout menghapus inventaris', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final record = InventoryRecord.fromApi(
      {
        'id_inventaris': '1',
        'public_id': null,
        'version': null,
        'id_jenis_inventaris': '1',
        'id_obat': null,
        'nama_barang': 'Pupuk Uji',
        'satuan': 'kg',
        'stok_minimum': '1',
        'status_aktif': 1,
        'nama_jenis': 'Pupuk',
        'nama_obat': null,
      },
      {
        'id_inventaris': '1',
        'satuan': 'kg',
        'saldo': '0.25',
        'stok_minimum': '1',
        'di_bawah_minimum': true,
      },
    );
    final api = ApiClient(
      MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          return respond({
            'data': {
              'access_token': 'access',
              'refresh_token': 'refresh',
              'user': {
                'id_user': '1',
                'nama': 'Mitra',
                'username': 'mitra',
                'role': 'petani',
                'permissions': ['inventaris:read'],
              },
            },
          });
        }
        if (request.url.path.endsWith('/penyemaian')) {
          return respond({'data': []});
        }
        return respond({'data': {}});
      }),
      baseUri: Uri.parse('https://example.test/api/v1'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          connectedInventoryProvider.overrideWith(
            (ref) => ConnectedInventoryViewModel(
              InventoryRepository(
                api,
                Completer<InventoryCache>().future,
                userId: '1',
              ),
              initialState: ConnectedInventoryState(records: [record]),
              autoLoad: false,
            ),
          ),
        ],
        child: const MaterialApp(home: AppGate()),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'mitra');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Masuk'));
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    // Pastikan masuk ke MainPage (Beranda aktif)
    expect(find.text('HidroSense'), findsOneWidget);
    expect(find.text('Inventaris'), findsOneWidget);

    // Navigasi ke tab Inventaris
    await tester.tap(find.text('Inventaris'));
    await tester.pumpAndSettle();

    expect(find.text('Pupuk Uji'), findsOneWidget);
    expect(find.textContaining('0.25 kg'), findsOneWidget);

    // Buka detail item dialog
    await tester.tap(find.text('Pupuk Uji'));
    await tester.pumpAndSettle();
    expect(find.text('Stok minimum: 1 kg'), findsOneWidget);
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();

    // Buka halaman Akun melalui Header icon
    await tester.tap(find.byTooltip('Buka akun'));
    await tester.pumpAndSettle();
    expect(find.text('Pengguna'), findsOneWidget);
    expect(find.text('Mitra'), findsOneWidget);
    expect(find.text('Petani'), findsOneWidget);

    // Logout dari halaman akun
    await tester.ensureVisible(find.text('Keluar Dari Akun'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keluar Dari Akun'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Pupuk Uji'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    api.close();
  });
}

http.Response respond(Object body) => http.Response(jsonEncode(body), 200);
