// Regresi BUG-40 & BUG-41 di Detail meja.
//
// BUG-40: "Tambah tanaman" menyaring semaian dengan `SowingRecord.canTransfer`
// (butuh server menandai `siap_pindah`), sedangkan daftar semaian memakai HSS
// (≥ 15 hari). Akibatnya semaian yang siap pindah tidak muncul di pemilih meja.
//
// BUG-41: tombol "Lihat semaian" di pemilih membawa pengguna kembali ke Detail
// meja, bukan ke daftar semaian.
//
// Bukti gagal di kode lama: tes BUG-40 memakai semaian HSS 17 tanpa tanda
// `siap_pindah` — pemilih kosong di kode lama. Tes BUG-41 menekan "Lihat
// semaian" dan mengharapkan daftar semaian; kode lama hanya menutup pemilih.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/nursery_record.dart';
import 'package:hidrosense_mobile/data/models/transfer_record.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/data/services/inventory_cache.dart';
import 'package:hidrosense_mobile/viewmodels/connected_inventory_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_semaian_row.dart';
import 'package:hidrosense_mobile/views/v2/connected/v2_meja_connected.dart';
import 'package:hidrosense_mobile/views/v2/connected/v2_semaian_connected.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object body) => http.Response(jsonEncode(body), 200);

const _user = SessionUser(
  id: '1',
  name: 'Mitra',
  username: 'mitra',
  role: 'petani',
  permissions: [
    'budidaya:read',
    'budidaya:write',
    'penyemaian:read',
    'penyemaian:write',
    'inventaris:read',
    'panen:read',
  ],
);

/// Semaian HSS 17 yang belum ditandai siap pindah oleh server.
const _sowing = SowingRecord(
  id: '7',
  userId: '1',
  sowingDate: '2026-11-08',
  seedCount: 200,
  remainingSeedCount: 190,
  status: 'aktif',
  ageDays: 17,
  isReadyToMove: false,
);

/// Semaian HSS 5: belum siap pindah.
const _sowingMuda = SowingRecord(
  id: '8',
  userId: '1',
  sowingDate: '2026-11-20',
  seedCount: 200,
  remainingSeedCount: 200,
  status: 'aktif',
  ageDays: 5,
  isReadyToMove: false,
);

ApiClient _api() {
  Map<String, dynamic> tableJson() => {
    'id_meja': '1',
    'kode_meja': 'A1',
    'jumlah_lubang': 200,
    'status_meja': 'tersedia',
    'tanaman_aktif': 40,
    'kapasitas_tersedia': 160,
  };
  final api = ApiClient(
    MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/meja-tanam/1')) {
        return _json({'data': tableJson()});
      }
      if (path.endsWith('/meja-tanam')) {
        return _json({
          'data': [tableJson()],
          'meta': {'page': 1, 'limit': 50, 'total': 1, 'total_pages': 1},
        });
      }
      return _json({
        'data': <Object>[],
        'meta': {'page': 1, 'limit': 20, 'total': 0, 'total_pages': 0},
      });
    }),
    baseUri: Uri.parse('https://example.test/api/v1'),
  )..setTokens(accessToken: 'a', refreshToken: 'r');
  return api;
}

Future<void> _pumpDetail(
  WidgetTester tester,
  ApiClient api, {
  List<SowingRecord> sowings = const <SowingRecord>[_sowing, _sowingMuda],
}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        inventoryCacheProvider.overrideWithValue(
          Completer<InventoryCache>().future,
        ),
        sessionProvider.overrideWith(
          (ref) =>
              SessionViewModel(api, initialState: const SessionState(user: _user)),
        ),
        v2AllSowingsProvider.overrideWith(
          (ref) async => sowings,
        ),
        v2AllTransfersProvider.overrideWith(
          (ref) async => const <TransferRecord>[],
        ),
      ],
      child: const MaterialApp(
        home: V2MejaConnectedDetailPage(tableId: '1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'BUG-40: semaian HSS 17 tetap ditawarkan walau server belum menandai siap',
    (tester) async {
      final api = _api();
      addTearDown(api.close);
      await _pumpDetail(tester, api);

      await tester.tap(find.text('Tambah tanaman'));
      await tester.pumpAndSettle();

      expect(
        find.byType(V2SemaianRow),
        findsOneWidget,
        reason: 'semaian HSS 17 harus muncul di pemilih "Tambah tanaman"',
      );
      expect(find.text('Belum ada yang siap'), findsNothing);
    },
  );

  testWidgets('BUG-41: "Lihat semaian" membuka daftar semaian', (tester) async {
    final api = _api();
    addTearDown(api.close);
    await _pumpDetail(
      tester,
      api,
      sowings: const <SowingRecord>[_sowingMuda],
    );

    await tester.tap(find.text('Tambah tanaman'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada yang siap'), findsOneWidget);

    await tester.tap(find.text('Lihat semaian'));
    await tester.pumpAndSettle();

    expect(
      find.byType(V2SemaianConnectedListPage),
      findsOneWidget,
      reason: 'BUG-41: "Lihat semaian" harus membuka daftar semaian',
    );
  });
}