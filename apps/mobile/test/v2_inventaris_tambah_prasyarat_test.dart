// Regresi K-07/K-08: tombol "Tambah barang" tidak boleh menunggu jaringan dulu
// (daftar obat/kategori dimuat sejak tab dibuka), dan saat server tidak punya
// kategori aktif form tidak boleh dibuka lalu gagal setelah isian penuh.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/repositories/inventory_repository.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/data/services/inventory_cache.dart';
import 'package:hidrosense_mobile/viewmodels/connected_inventory_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/views/v2/connected/v2_inventaris_connected.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _user = SessionUser(
  id: '1',
  name: 'Petani',
  username: 'petani',
  role: 'petani',
  permissions: ['inventaris:read', 'inventaris:write'],
);

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> _page(List<Object> data) => {
  'data': data,
  'meta': {'page': 1, 'limit': 100, 'total': data.length, 'total_pages': 1},
};

Future<List<String>> _pumpTab(
  WidgetTester tester, {
  required bool kategoriKosong,
}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final paths = <String>[];
  final api = ApiClient(
    MockClient((request) async {
      final path = request.url.path;
      paths.add(path);
      if (path.endsWith('/inventaris')) return _json(_page(const []));
      if (path.endsWith('/obat')) return _json(_page(const []));
      if (path.endsWith('/jenis-inventaris')) {
        return _json(
          kategoriKosong
              ? _page(const [])
              : _page([
                  {
                    'id_jenis_inventaris': '1',
                    'nama_jenis': 'Benih',
                    'status_aktif': 1,
                  },
                ]),
        );
      }
      return _json(_page(const []));
    }),
    baseUri: Uri.parse('https://example.test/api/v1'),
  )..setTokens(accessToken: 'a', refreshToken: 'r');
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
        connectedInventoryProvider.overrideWith(
          (ref) => ConnectedInventoryViewModel(
            InventoryRepository(
              api,
              Completer<InventoryCache>().future,
              userId: '1',
            ),
            autoLoad: false,
          ),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(body: V2InventarisConnectedTab()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return paths;
}

void main() {
  testWidgets('daftar kategori & obat dimuat sejak tab dibuka (K-07)', (
    tester,
  ) async {
    final paths = await _pumpTab(tester, kategoriKosong: false);

    expect(
      paths.any((path) => path.endsWith('/jenis-inventaris')),
      isTrue,
      reason: 'Kategori belum dimuat sebelum tombol Tambah ditekan',
    );
    expect(
      paths.any((path) => path.endsWith('/obat')),
      isTrue,
      reason: 'Daftar obat belum dimuat sebelum tombol Tambah ditekan',
    );

    await tester.tap(find.text('Tambah barang'));
    await tester.pumpAndSettle();
    // Form 4.10 terbuka tanpa menunggu permintaan baru.
    expect(find.text('Jenis'), findsOneWidget);
  });

  testWidgets('tanpa kategori aktif, Tambah barang menjelaskan prasyarat (K-08)', (
    tester,
  ) async {
    await _pumpTab(tester, kategoriKosong: true);

    await tester.tap(find.text('Tambah barang'));
    await tester.pumpAndSettle();

    expect(find.text(v2KategoriKosongPesan), findsOneWidget);
    expect(
      find.text('Tambah barang'),
      findsOneWidget,
      reason: 'Form 4.10 tidak boleh terbuka saat kategori kosong',
    );
  });
}