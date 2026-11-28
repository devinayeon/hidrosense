// Regresi sesi 13: arsip barang dari tab Stok tersambung harus memberi pesan
// sukses setelah proses selesai, dan jalur gagal harus tetap memberi pesan
// serta membiarkan halaman detail terbuka.
//
// Di kode lama `_bukaDetail` hanya menangani pemulihan arsip, jadi arsip baru
// menutup halaman tanpa SnackBar apa pun.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/inventory_record.dart';
import 'package:hidrosense_mobile/data/repositories/inventory_repository.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/data/services/inventory_cache.dart';
import 'package:hidrosense_mobile/viewmodels/connected_inventory_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/views/v2/connected/v2_inventaris_connected.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _user = SessionUser(
  id: '1',
  name: 'Petani',
  username: 'petani',
  role: 'petani',
  permissions: ['inventaris:read', 'inventaris:write'],
);

Map<String, dynamic> _recordJson() => {
  'id_inventaris': '1',
  'public_id': null,
  'version': null,
  'id_jenis_inventaris': '1',
  'id_obat': null,
  'id_katalog': null,
  'nama_barang': 'Benih Uji',
  'satuan': 'pak',
  'stok_minimum': '3',
  'status_aktif': 1,
  'nama_jenis': 'Benih',
  'nama_obat': null,
  'nama_katalog': null,
  'saldo': '12',
  // Endpoint `/inventaris` mengirim master sekaligus saldo, jadi penguraian
  // `fromApi(master, master)` membutuhkan `di_bawah_minimum` juga.
  'di_bawah_minimum': false,
};

http.Response _json(Object body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> _page(List<Object> data) => {
  'data': data,
  'meta': {'page': 1, 'limit': 100, 'total': data.length, 'total_pages': 1},
};

/// Cache inventaris di memori. Setelah arsip berhasil, viewmodel menyegarkan
/// daftar dan menulis hasilnya ke cache, jadi cache harus benar-benar selesai
/// (bukan `Completer` yang tak pernah dipenuhi) supaya penyegaran tuntas.
Future<InventoryCache> _openCache() async => InventoryCache(
  await databaseFactoryFfiNoIsolate.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      singleInstance: false,
      onCreate: InventoryCache.createSchema,
    ),
  ),
);

/// Tab Stok tersambung dengan satu barang aktif. [arsipGagal] membuat POST
/// deactivate menjawab 500 supaya jalur gagal bisa diuji.
Future<void> _pumpTab(WidgetTester tester, {bool arsipGagal = false}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final cache = await _openCache();
  addTearDown(cache.close);
  final record = InventoryRecord.fromJson(_recordJson());
  final api = ApiClient(
    MockClient((request) async {
      final path = request.url.path;
      if (request.method == 'POST' && path.endsWith('/inventaris/1/deactivate')) {
        if (arsipGagal) {
          return _json({
            'error': {
              'code': 'SERVER_ERROR',
              'message': 'Arsip gagal diproses.',
            },
          }, status: 500);
        }
        return _json({'data': <String, dynamic>{}});
      }
      if (path.endsWith('/inventaris')) return _json(_page([_recordJson()]));
      if (path.endsWith('/stok')) {
        return _json({
          'data': <Object>[],
          'meta': {'page': 1, 'limit': 1, 'total': 0, 'total_pages': 0},
        });
      }
      if (path.endsWith('/obat-katalog')) return _json(_page(const []));
      if (path.endsWith('/jenis-inventaris')) {
        return _json(
          _page([
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
        inventoryCacheProvider.overrideWithValue(Future.value(cache)),
        sessionProvider.overrideWith(
          (ref) => SessionViewModel(
            api,
            initialState: const SessionState(user: _user),
          ),
        ),
        connectedInventoryProvider.overrideWith(
          (ref) => ConnectedInventoryViewModel(
            InventoryRepository(api, Future.value(cache), userId: '1'),
            autoLoad: false,
            initialState: ConnectedInventoryState(records: [record]),
          ),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(body: V2InventarisConnectedTab()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Buka detail barang lalu tekan "Arsipkan" dan konfirmasi.
Future<void> _arsipkan(WidgetTester tester) async {
  await tester.tap(find.text('Benih Uji'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Arsipkan'));
  await tester.pumpAndSettle();
  // Tombol utama dialog memakai label yang sama; ambil yang di dalam dialog.
  await tester.tap(find.text('Arsipkan').last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets('arsip berhasil memberi SnackBar "Benih Uji diarsipkan."', (
    tester,
  ) async {
    await _pumpTab(tester);
    await _arsipkan(tester);

    expect(find.text('Benih Uji diarsipkan.'), findsOneWidget);
    expect(find.text('Detail barang'), findsNothing);
  });

  testWidgets('arsip gagal: halaman tetap terbuka dan pesan galat tampil', (
    tester,
  ) async {
    await _pumpTab(tester, arsipGagal: true);
    await _arsipkan(tester);

    expect(find.text('Detail barang'), findsOneWidget);
    expect(find.text('Benih Uji diarsipkan.'), findsNothing);
    expect(find.text('Arsip gagal diproses.'), findsOneWidget);
  });
}