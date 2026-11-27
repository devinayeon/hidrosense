// Regresi permintaan 27 Nov 2026 untuk tab Rawat:
// 1. foto tanpa hama berlabel "Tidak terdeteksi", bukan "Tanpa keyakinan";
// 2. detail pindaian tanpa hama tidak menawarkan jalan ke riwayat rotasi obat;
// 3. potongan stok dari rekomendasi yang diterima muncul di kartu "Riwayat".
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/repositories/inventory_repository.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/data/services/inventory_cache.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_rawat_data.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_pindai_detail_page.dart';
import 'package:hidrosense_mobile/views/v2/theme/v2_tokens.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _movement(int id, {String direction = 'keluar'}) => {
  'id_stok': '$id',
  'id_user': '1',
  'tanggal_stok': '2026-11-24T02:00:00.000Z',
  'jenis_stok': direction,
  'keterangan': direction == 'keluar' ? 'Perawatan #$id' : null,
  'reversal_of': null,
  'details': [
    {
      'id_detail_stok': '$id',
      'id_inventaris': '7',
      'jumlah': '10',
      'satuan': 'ml',
    },
  ],
};

V2PindaiItem _item({String? hama, int? keyakinan}) => V2PindaiItem(
  id: '3',
  hama: hama ?? v2PindaiTanpaHama,
  meja: 'Meja A2',
  tanggal: DateTime(2026, 11, 24),
  keyakinan: keyakinan,
);

void main() {
  group('label pindaian', () {
    test('foto tanpa hama memakai "Tidak terdeteksi"', () {
      expect(_item().adaHama, isFalse);
      expect(_item().labelKeyakinan, 'Tidak terdeteksi');
    });

    test('hama tanpa skor tetap "Tanpa keyakinan"', () {
      final item = _item(hama: 'Thrips', keyakinan: null);
      expect(item.adaHama, isTrue);
      expect(item.labelKeyakinan, 'Tanpa keyakinan');
    });

    test('hama dengan skor menampilkan persen', () {
      expect(_item(hama: 'Thrips', keyakinan: 87).labelKeyakinan, '87%');
    });
  });

  group('detail pindaian', () {
    testWidgets('tanpa hama: tanpa tombol riwayat rotasi', (tester) async {
      var dibuka = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: V2Theme.light,
          home: V2PindaiDetailPage(item: _item(), onOpenRotasi: () => dibuka++),
        ),
      );

      expect(find.text('Tidak ada hama'), findsOneWidget);
      expect(find.text('Tidak terdeteksi'), findsOneWidget);
      expect(find.text('Keyakinan Tidak terdeteksi'), findsNothing);
      expect(find.text('Lihat riwayat rotasi obat'), findsNothing);
      expect(dibuka, 0);
    });

    testWidgets('ada hama: tombol riwayat rotasi tetap ada', (tester) async {
      var dibuka = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: V2Theme.light,
          home: V2PindaiDetailPage(
            item: _item(hama: 'Thrips', keyakinan: 87),
            onOpenRotasi: () => dibuka++,
          ),
        ),
      );

      expect(find.text('Keyakinan 87%'), findsOneWidget);
      expect(find.text('Lihat riwayat rotasi obat'), findsOneWidget);
      await tester.tap(find.text('Lihat riwayat rotasi obat'));
      expect(dibuka, 1);
    });
  });

  group('riwayat stok', () {
    test(
      'potongan terbaru diambil dari halaman terakhir, terbaru dulu',
      () async {
        final requested = <Uri>[];
        final api = ApiClient(
          MockClient((request) async {
            requested.add(request.url);
            final page = int.parse(request.url.queryParameters['page']!);
            final limit = int.parse(request.url.queryParameters['limit']!);
            final total = 45;
            if (limit == 1) {
              return http.Response(
                jsonEncode({
                  'data': [_movement(45)],
                  'meta': {
                    'page': 1,
                    'limit': 1,
                    'total': total,
                    'total_pages': total,
                  },
                }),
                200,
              );
            }
            final start = (page - 1) * limit + 1;
            final end = (start + limit - 1).clamp(1, total);
            return http.Response(
              jsonEncode({
                'data': [for (var id = start; id <= end; id++) _movement(id)],
                'meta': {
                  'page': page,
                  'limit': limit,
                  'total': total,
                  'total_pages': (total + limit - 1) ~/ limit,
                },
              }),
              200,
            );
          }),
          baseUri: Uri.parse('https://example.test/api/v1'),
        )..setTokens(accessToken: 'access', refreshToken: 'refresh');
        final repo = InventoryRepository(
          api,
          Completer<InventoryCache>().future,
          userId: '1',
        );

        final rows = await repo.fetchLatestStockHistory(inventoryId: '7');

        expect(rows, hasLength(20));
        expect(rows.take(5).map((row) => row.id), [
          '45',
          '44',
          '43',
          '42',
          '41',
        ]);
        expect(rows.first.direction, 'keluar');
        expect(requested.skip(1).map((url) => url.queryParameters['page']), [
          '2',
          '3',
        ]);
      },
    );

    test(
      'tiga terbaru tetap utuh saat halaman terakhir cuma berisi satu',
      () async {
        final requested = <Uri>[];
        final api = ApiClient(
          MockClient((request) async {
            requested.add(request.url);
            final page = int.parse(request.url.queryParameters['page']!);
            final limit = int.parse(request.url.queryParameters['limit']!);
            const total = 21;
            if (limit == 1) {
              return http.Response(
                jsonEncode({
                  'data': [_movement(total)],
                  'meta': {
                    'page': 1,
                    'limit': 1,
                    'total': total,
                    'total_pages': total,
                  },
                }),
                200,
              );
            }
            final start = (page - 1) * limit + 1;
            final end = (start + limit - 1).clamp(1, total);
            return http.Response(
              jsonEncode({
                'data': [for (var id = start; id <= end; id++) _movement(id)],
                'meta': {
                  'page': page,
                  'limit': limit,
                  'total': total,
                  'total_pages': (total + limit - 1) ~/ limit,
                },
              }),
              200,
            );
          }),
          baseUri: Uri.parse('https://example.test/api/v1'),
        )..setTokens(accessToken: 'access', refreshToken: 'refresh');
        final repo = InventoryRepository(
          api,
          Completer<InventoryCache>().future,
          userId: '1',
        );

        final rows = await repo.fetchLatestStockHistory(inventoryId: '7');

        expect(rows, hasLength(20));
        expect(rows.take(3).map((row) => row.id), ['21', '20', '19']);
        expect(requested.map((url) => url.queryParameters['page']), [
          '1',
          '1',
          '2',
        ]);
      },
    );

    test('tanpa riwayat tidak meminta halaman kedua', () async {
      final requested = <Uri>[];
      final api = ApiClient(
        MockClient((request) async {
          requested.add(request.url);
          return http.Response(
            jsonEncode({
              'data': <Object>[],
              'meta': {'page': 1, 'limit': 1, 'total': 0, 'total_pages': 0},
            }),
            200,
          );
        }),
        baseUri: Uri.parse('https://example.test/api/v1'),
      )..setTokens(accessToken: 'access', refreshToken: 'refresh');
      final repo = InventoryRepository(
        api,
        Completer<InventoryCache>().future,
        userId: '1',
      );

      expect(await repo.fetchLatestStockHistory(inventoryId: '7'), isEmpty);
      expect(requested, hasLength(1));
    });
  });
}
