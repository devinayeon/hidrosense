// Regresi BUG-34: setelah "Pindah ke meja" berhasil, meja/pemindahan/penyemaian
// harus dimuat ulang — kalau tidak, form "sisa" dan Detail meja menampilkan
// data basi. Uji ini memastikan (a) tombol "Pindahkan sisa" mengembalikan aksi
// ke pemanggil (bukan membuka form lagi dengan daftar meja lama), dan
// (b) segarkan-setelah-tulis benar-benar memuat ulang pemindahan/penyemaian.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_semaian_data.dart';
import 'package:hidrosense_mobile/views/v2/connected/v2_meja_connected.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_pindah_meja_page.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object body) => http.Response(jsonEncode(body), 200);

Map<String, dynamic> _tableJson() => {
  'id_meja': '1',
  'kode_meja': 'A1',
  'jumlah_lubang': 200,
  'status_meja': 'tersedia',
  'tanaman_aktif': 40,
  'kapasitas_tersedia': 160,
};

void main() {
  testWidgets('"Pindahkan sisa" mengembalikan aksi ke pemanggil (BUG-34a)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    V2SemaianPindah? hasil;
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
                      jumlahAwal: 120,
                      daftarMeja: const [
                        V2SemaianMeja(
                          nama: 'Meja A2',
                          lubangKosong: 200,
                          tableId: '2',
                        ),
                      ],
                      onPindahkan: (_) async {},
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
    await tester.pumpAndSettle();
    expect(find.text('Pindahkan sisa'), findsOneWidget);

    await tester.tap(find.text('Pindahkan sisa'));
    await tester.pumpAndSettle();

    expect(hasil, isNotNull, reason: 'aksi tidak kembali ke pemanggil');
    expect(hasil!.aksi, V2PindahMejaAksi.pindahkanSisa);
  });

  testWidgets('segarkan-setelah-tulis memuat ulang pemindahan & meja (BUG-34)',
      (tester) async {
    var transferCalls = 0;
    var tableCalls = 0;
    var sowingCalls = 0;
    final api = ApiClient(
      MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/auth/login')) {
          return _json({
            'data': {
              'access_token': 'access',
              'refresh_token': 'refresh',
              'user': {
                'id_user': '1',
                'nama': 'Mitra',
                'username': 'mitra',
                'role': 'petani',
                'permissions': [
                  'budidaya:read',
                  'budidaya:write',
                  'penyemaian:read',
                  'panen:read',
                ],
              },
            },
          });
        }
        if (path.endsWith('/meja-tanam/1')) {
          tableCalls++;
          return _json({'data': _tableJson()});
        }
        if (path.endsWith('/meja-tanam')) {
          tableCalls++;
          return _json({
            'data': [_tableJson()],
            'meta': {'page': 1, 'limit': 50, 'total': 1, 'total_pages': 1},
          });
        }
        if (path.endsWith('/pemindahan')) {
          transferCalls++;
          return _json({
            'data': <Object>[],
            'meta': {'page': 1, 'limit': 100, 'total': 0, 'total_pages': 0},
          });
        }
        if (path.endsWith('/penyemaian')) {
          sowingCalls++;
          return _json({
            'data': <Object>[],
            'meta': {'page': 1, 'total': 0, 'total_pages': 0},
          });
        }
        return _json({'data': {}});
      }),
      baseUri: Uri.parse('https://example.test/api/v1'),
    );
    addTearDown(api.close);

    late WidgetRef captured;
    final session = SessionViewModel(api, openStore: () async => null);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          sessionProvider.overrideWith((ref) => session),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              captured = ref;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Masuk supaya ApiClient punya token; tanpa itu permintaan ditolak lokal.
    await session.login('mitra', 'secret');
    await tester.pumpAndSettle();

    // Muat awal: satu kali panggil daftar pemindahan.
    await captured.read(v2AllTransfersProvider.future);
    expect(transferCalls, 1);

    // Segarkan setelah tulis: pemindahan & penyemaian dimuat ulang, meja disegarkan.
    await v2SegarkanSetelahTulis(captured);
    expect(transferCalls, 2, reason: 'pemindahan tidak dimuat ulang');
    expect(sowingCalls, greaterThanOrEqualTo(1));
    expect(tableCalls, greaterThanOrEqualTo(2));
  });
}
