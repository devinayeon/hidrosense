// Regresi BUG-35 (keputusan D-25): tombol "Tambah tanaman" di Detail meja TIDAK
// mengisi meja secara langsung; ia membuka form "Pindah ke meja" dengan default
// meja ini terpilih dan jumlah = min(sisa bibit, kapasitas meja), lalu menyimpan
// lewat alur pindah.
//
// Bukti gagal di kode lama: form "Pindah ke meja" tidak pernah muncul dan POST
// /pemindahan langsung terkirim. Parameter `showResultPage` juga belum ada di
// kode lama sehingga tes tidak akan ter-compile.
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
import 'package:hidrosense_mobile/views/v2/components/v2_meja_data.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_semaian_data.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_semaian_row.dart';
import 'package:hidrosense_mobile/views/v2/connected/v2_meja_connected.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_pindah_meja_page.dart';
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
    'panen:read',
  ],
);

const _sowing = SowingRecord(
  id: '7',
  userId: '1',
  sowingDate: '2026-11-01',
  seedCount: 200,
  status: 'aktif',
  ageDays: 17,
  isReadyToMove: true,
);

void main() {
  testWidgets(
    '"Tambah tanaman" membuka form Pindah ke meja lalu menyimpan lewat alur pindah (BUG-35)',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      var postCount = 0;
      var tableActive = 40;
      Map<String, dynamic> tableJson() => {
        'id_meja': '1',
        'kode_meja': 'A1',
        'jumlah_lubang': 200,
        'status_meja': tableActive >= 200 ? 'penuh' : 'tersedia',
        'tanaman_aktif': tableActive,
        'kapasitas_tersedia': 200 - tableActive,
      };

      final api = ApiClient(
        MockClient((request) async {
          final path = request.url.path;
          if (request.method == 'POST' && path.endsWith('/pemindahan')) {
            postCount++;
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final count = body['jumlah_tanaman'] as int;
            tableActive += count;
            return _json({
              'data': {
                'id_pemindahan': '5',
                'id_meja': body['id_meja'],
                'id_penyemaian': body['id_penyemaian'],
                'tanggal_pemindahan': body['tanggal_pemindahan'],
                'jumlah_tanaman': count,
                'tanaman_aktif': count,
              },
            });
          }
          if (path.endsWith('/meja-tanam/1')) {
            return _json({'data': tableJson()});
          }
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
              (ref) async => const <SowingRecord>[_sowing],
            ),
            v2AllTransfersProvider.overrideWith(
              (ref) async => const <TransferRecord>[],
            ),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                // Pastikan daftar penyemaian termuat seperti di aplikasi nyata
                // (tab Tanam) sebelum detail meja dibuka.
                ref.watch(v2AllSowingsProvider);
                return const V2MejaConnectedDetailPage(
                  item: V2MejaItem(
                    id: '1',
                    kode: 'A1',
                    jumlahLubang: 200,
                    terisi: 40,
                    status: V2MejaStatus.tersedia,
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1) Tombol "Tambah tanaman" membuka pemilih semaian.
      await tester.tap(find.text('Tambah tanaman'));
      await tester.pumpAndSettle();
      expect(find.text('Pilih semaian'), findsOneWidget);

      // 2) Pilih semaian -> form "Pindah ke meja" muncul, belum ada tulis.
      await tester.tap(find.byType(V2SemaianRow).first);
      await tester.pumpAndSettle();
      expect(
        find.text('Pindah ke meja'),
        findsOneWidget,
        reason: 'BUG-35: harus lewat form pindah, bukan mengisi langsung',
      );
      expect(postCount, 0, reason: 'BUG-35: belum boleh menyimpan saat form baru dibuka');

      // 3) Simpan lewat alur pindah; tanpa halaman hasil (konteks Detail meja).
      await tester.tap(find.text('Pindahkan'));
      // Tombol "Pindahkan" form berputar selama dialog terbuka.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Pindahkan').last);
      await tester.pumpAndSettle();
      expect(postCount, 1, reason: 'penyimpanan harus lewat POST /pemindahan');
      expect(
        find.text('Lihat meja'),
        findsNothing,
        reason: 'alur Tambah tanaman tidak menampilkan halaman hasil pindah',
      );
      expect(find.text('Tanaman ditambahkan.'), findsOneWidget);
    },
  );

  testWidgets(
    'form pindah showResultPage:false menutup dan mengembalikan aksi (BUG-35)',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      V2SemaianPindah? hasil;
      var kirim = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  hasil = await Navigator.of(context).push<V2SemaianPindah>(
                    MaterialPageRoute<V2SemaianPindah>(
                      builder: (_) => V2PindahMejaFormPage(
                        item: designSemaianRomaineSiapPindah,
                        jumlahAwal: 100,
                        daftarMeja: const [
                          V2SemaianMeja(
                            nama: 'Meja A2',
                            lubangKosong: 200,
                            tableId: '2',
                          ),
                        ],
                        showResultPage: false,
                        onPindahkan: (_) async => kirim++,
                      ),
                    ),
                  );
                },
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pindahkan'));
      // Tombol "Pindahkan" form berputar selama dialog terbuka.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Pindahkan').last);
      await tester.pumpAndSettle();

      expect(kirim, 1);
      expect(hasil, isNotNull);
      expect(hasil!.jumlah, 100);
      expect(hasil!.tableId, '2');
      expect(find.text('Lihat meja'), findsNothing);
    },
  );
}
