// Sesi 11: (1) bawaan "Pindah ke meja" = meja paling atas hasil urutan lubang
// kosong, bukan entri pertama daftar mentah (dulu selalu M-02); (2) kartu
// "Tanaman di meja" menampilkan kerangka pemuatan, bukan "Belum ada tanaman di
// meja ini." saat data masih dimuat.
//
// Bukti gagal di kode lama:
// - `mejaAwal` bawaan 0 memilih `sumber[0]` (M-02), jadi tes bawaan memilih
//   M-01 gagal.
// - Detail meja tersambung menampilkan "Belum ada tanaman di meja ini." selama
//   `v2AllTransfersProvider` masih tertunda.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/nursery_record.dart';
import 'package:hidrosense_mobile/data/models/transfer_record.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_semaian_data.dart';
import 'package:hidrosense_mobile/views/v2/connected/v2_meja_connected.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_pindah_meja_page.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_option_row.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_skeleton.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object body) => http.Response(jsonEncode(body), 200);

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pumpAndSettle();
}

const _user = SessionUser(
  id: '1',
  name: 'Mitra',
  username: 'mitra',
  role: 'petani',
  permissions: [
    'budidaya:read',
    'budidaya:write',
    'penyemaian:read',
    'inventaris:read',
    'panen:read',
  ],
);

void main() {
  testWidgets('bawaan pindah memilih meja paling atas hasil urutan', (
    tester,
  ) async {
    await _pump(
      tester,
      V2PindahMejaFormPage(
        item: designSemaianRomaineSiapPindah,
        // Urutan mentah menaruh M-02 lebih dulu; dulu inilah yang terpilih.
        daftarMeja: const <V2SemaianMeja>[
          V2SemaianMeja(nama: 'M-02', lubangKosong: 100, tableId: 'm02'),
          V2SemaianMeja(nama: 'M-01', lubangKosong: 300, tableId: 'm01'),
        ],
      ),
    );

    final rows = tester
        .widgetList<V2OptionRow>(find.byType(V2OptionRow))
        .toList();
    expect(rows.map((row) => row.label.split(',').first).toList(), [
      'M-01',
      'M-02',
    ], reason: 'meja tersedia diurutkan lubang kosong terbanyak dulu (D-27)');
    final terpilih = rows
        .where((row) => row.state == V2OptionState.selected)
        .map((row) => row.label.split(',').first)
        .toList();
    expect(
      terpilih,
      ['M-01'],
      reason:
          'bawaan harus meja paling atas, bukan entri pertama daftar mentah',
    );
  });

  testWidgets('kartu tanaman menampilkan kerangka saat data masih dimuat', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();

    // Pemindahan ditahan sampai tes selesai: inilah keadaan "sedang memuat".
    final transfers = Completer<List<TransferRecord>>();
    final api = ApiClient(
      MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/meja-tanam')) {
          return _json({
            'data': [
              {
                'id_meja': '1',
                'kode_meja': 'A1',
                'jumlah_lubang': 200,
                'status_meja': 'tersedia',
                'tanaman_aktif': 40,
                'kapasitas_tersedia': 160,
              },
            ],
            'meta': {'page': 1, 'limit': 50, 'total': 1, 'total_pages': 1},
          });
        }
        return _json({
          'data': <Object>[],
          'meta': {'page': 1, 'limit': 20, 'total': 0, 'total_pages': 0},
        });
      }),
      baseUri: Uri.parse('https://example.test/api/v1'),
    );
    api.setTokens(accessToken: 'a', refreshToken: 'r');
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
          v2AllTransfersProvider.overrideWith((ref) => transfers.future),
          v2AllSowingsProvider.overrideWith(
            (ref) async => const <SowingRecord>[],
          ),
        ],
        child: const MaterialApp(home: V2MejaConnectedDetailPage(tableId: '1')),
      ),
    );
    // Jangan pumpAndSettle: animasi kerangka berulang terus.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Meja sudah termuat, tetapi daftar tanaman belum.
    expect(find.text('Terisi 40'), findsOneWidget);
    expect(
      find.text('Belum ada tanaman di meja ini.'),
      findsNothing,
      reason: 'data yang masih dimuat bukan berarti meja kosong',
    );
    expect(find.byType(V2Skeleton), findsWidgets);
    expect(find.bySemanticsLabel('Memuat tanaman di meja'), findsOneWidget);
    semantics.dispose();

    // Setelah data datang, kerangka berganti baris tanaman.
    transfers.complete([
      TransferRecord(
        id: '5',
        tableId: '1',
        sowingId: '7',
        transferDate: '2026-11-01',
        plantCount: 40,
        activePlants: 40,
      ),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(V2Skeleton), findsNothing);
    expect(find.text('Belum ada tanaman di meja ini.'), findsNothing);
    expect(find.text('Tanaman meja'), findsOneWidget);
  });
}
