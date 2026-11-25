// Regresi BUG-39: Detail meja yang dibuka dari halaman sukses "Pindah ke meja"
// bisa menampilkan data basi/kosong karena halaman memegang salinan objek yang
// dibuat sekali. Perbaikannya: satu pintu masuk bersama `bukaDetailMeja` yang
// membuka Detail meja lewat id, lalu halaman selalu membaca ulang dari provider.
//
// Bukti gagal di kode lama: konstruktor belum punya parameter `tableId`, jadi
// tes ini tidak ter-compile pada kode lama.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/nursery_record.dart';
import 'package:hidrosense_mobile/data/models/transfer_record.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/viewmodels/connected_table_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/views/v2/connected/v2_meja_connected.dart';
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
    'inventaris:read',
    'panen:read',
  ],
);

void main() {
  testWidgets(
    'Detail meja dibuka lewat id selalu membaca ulang provider (BUG-39)',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      var aktif = 40;
      Map<String, dynamic> tableJson() => {
        'id_meja': '1',
        'kode_meja': 'A1',
        'jumlah_lubang': 200,
        'status_meja': 'tersedia',
        'tanaman_aktif': aktif,
        'kapasitas_tersedia': 200 - aktif,
      };

      final api = ApiClient(
        MockClient((request) async {
          final path = request.url.path;
          if (path.endsWith('/meja-tanam')) {
            return _json({
              'data': [tableJson()],
              'meta': {'page': 1, 'limit': 50, 'total': 1, 'total_pages': 1},
            });
          }
          if (path.endsWith('/inventaris')) {
            return _json({
              'data': <Object>[],
              'meta': {'page': 1, 'limit': 20, 'total': 0, 'total_pages': 0},
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

      late WidgetRef captured;
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
            v2AllTransfersProvider.overrideWith(
              (ref) async => const <TransferRecord>[],
            ),
            v2AllSowingsProvider.overrideWith(
              (ref) async => const <SowingRecord>[],
            ),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                captured = ref;
                // Tanpa `item`: halaman harus memuat sendiri dari provider.
                return const V2MejaConnectedDetailPage(tableId: '1');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Terisi 40'),
        findsOneWidget,
        reason: 'Detail meja belum memuat data meja dari provider',
      );

      // Data berubah di server (mis. pemindahan dari perangkat lain).
      aktif = 120;
      await captured.read(connectedTableProvider.notifier).refresh();
      await tester.pumpAndSettle();

      expect(
        find.text('Terisi 120'),
        findsOneWidget,
        reason: 'BUG-39: Detail meja memakai salinan lama, bukan data provider',
      );
      expect(find.text('Terisi 40'), findsNothing);
    },
  );
}