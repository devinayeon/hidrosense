import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/repositories/inventory_repository.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/data/services/inventory_cache.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

http.Response reply(int status, Object body) =>
    http.Response(jsonEncode(body), status);

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test(
    'new seed item saves stock 10 and minimum 5 with the required stock UUID',
    () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: InventoryCache.createSchema,
        ),
      );
      final cache = InventoryCache(db);
      var balance = '0';
      var creates = 0;
      var stockWrites = 0;
      final item = {
        ...master('1'),
        'nama_barang': 'Benih Buah Naga',
        'nama_jenis': 'Benih',
        'satuan': 'Pcs',
        'stok_minimum': '5',
      };
      final api = ApiClient(
        MockClient((request) async {
          final path = request.url.path;
          if (request.method == 'POST' && path.endsWith('/inventaris')) {
            creates++;
            expect(jsonDecode(request.body), {
              'id_jenis_inventaris': '1',
              'nama_barang': 'Benih Buah Naga',
              'satuan': 'Pcs',
              'stok_minimum': '5',
            });
            return reply(201, {'data': item});
          }
          if (request.method == 'POST' && path.endsWith('/stok')) {
            stockWrites++;
            expect(
              request.headers['Idempotency-Key'],
              matches(
                r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
              ),
            );
            expect(jsonDecode(request.body), {
              'jenis_stok': 'masuk',
              'details': [
                {'id_inventaris': '1', 'jumlah': '10', 'satuan': 'Pcs'},
              ],
              'keterangan': 'Saldo awal registrasi barang',
            });
            balance = '10';
            return reply(201, {
              'data': {
                'id_stok': '1',
                'id_user': '1',
                'tanggal_stok': '2026-10-08T12:00:00Z',
                'jenis_stok': 'masuk',
                'details': [
                  {
                    'id_detail_stok': '1',
                    'id_inventaris': '1',
                    'jumlah': '10',
                    'satuan': 'Pcs',
                  },
                ],
              },
            });
          }
          if (path.endsWith('/saldo')) {
            return reply(200, {
              'data': {
                'id_inventaris': '1',
                'satuan': 'Pcs',
                'saldo': balance,
                'stok_minimum': '5',
                'di_bawah_minimum': balance == '0',
              },
            });
          }
          return reply(200, {
            'data': [item],
            'meta': {'page': 1, 'total': 1, 'total_pages': 1},
          });
        }),
        baseUri: Uri.parse('https://example.test/api/v1'),
      )..setTokens(accessToken: 'access', refreshToken: 'refresh');
      addTearDown(() async {
        api.close();
        await cache.close();
      });
      final repository = InventoryRepository(
        api,
        Future.value(cache),
        userId: '1',
      );
      final created = await repository.createItem(
        categoryId: '1',
        name: 'Benih Buah Naga',
        unit: 'Pcs',
        minimum: '5',
      );
      await repository.recordStockMovement(
        direction: 'masuk',
        details: [
          {'id_inventaris': created.id, 'jumlah': '10', 'satuan': 'Pcs'},
        ],
        note: 'Saldo awal registrasi barang',
      );
      expect(creates, 1);
      expect(stockWrites, 1);
      final cached = (await repository.cached())!.records.single;
      expect(cached.balance, '10');
      expect(cached.minimum, '5');
      expect(cached.isLow, false);
    },
  );

  test(
    'all pages and exact balances replace cache only after full success',
    () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: InventoryCache.createSchema,
        ),
      );
      final cache = InventoryCache(db);
      var failSecondBalance = false;
      var shortSecondPage = false;
      final api = ApiClient(
        MockClient((request) async {
          final path = request.url.path;
          if (path.endsWith('/auth/login')) {
            return reply(200, {
              'data': {
                'access_token': 'a',
                'refresh_token': 'r',
                'user': {
                  'id_user': '1',
                  'nama': 'Pegawai',
                  'username': 'x',
                  'role': 'pegawai',
                  'permissions': ['inventaris:read'],
                },
              },
            });
          }
          if (path.endsWith('/inventaris')) {
            final page = int.parse(request.url.queryParameters['page']!);
            return reply(200, {
              'data': page == 2 && shortSecondPage
                  ? []
                  : [master(page.toString())],
              'meta': {'page': page, 'limit': 20, 'total': 2, 'total_pages': 2},
            });
          }
          if (failSecondBalance && path.endsWith('/2/saldo')) {
            return reply(503, {
              'error': {'code': 'NOT_READY', 'message': 'Belum siap'},
            });
          }
          final id = path.split('/')[4];
          return reply(200, {
            'data': {
              'id_inventaris': id,
              'satuan': 'kg',
              'saldo': id == '1' ? '0.25' : '2',
              'stok_minimum': '1',
              'di_bawah_minimum': id == '1',
            },
          });
        }),
        baseUri: Uri.parse('https://example.test/api/v1'),
      );
      await api.login('x', 'secret');
      final repository = InventoryRepository(
        api,
        Future.value(cache),
        userId: '1',
      );
      final first = await repository.refresh();
      expect(first.records.map((r) => r.balance), ['0.25', '2']);
      expect((await repository.cached())!.records.length, 2);
      failSecondBalance = true;
      await expectLater(repository.refresh(), throwsA(isA<ApiException>()));
      expect((await repository.cached())!.records.map((r) => r.balance), [
        '0.25',
        '2',
      ]);
      failSecondBalance = false;
      shortSecondPage = true;
      await expectLater(repository.refresh(), throwsA(isA<FormatException>()));
      expect((await repository.cached())!.records.length, 2);
      shortSecondPage = false;
      final delayedCache = Completer<InventoryCache>();
      final pending = InventoryRepository(
        api,
        delayedCache.future,
        userId: '1',
      ).refresh();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      api.clearSession();
      delayedCache.complete(cache);
      await expectLater(pending, throwsA(isA<ApiException>()));
      expect((await repository.cached())!.records.length, 2);
      api.close();
      await cache.close();
    },
  );
}

Map<String, dynamic> master(String id) => {
  'id_inventaris': id,
  'public_id': null,
  'version': null,
  'id_jenis_inventaris': '1',
  'id_obat': null,
  'nama_barang': 'Barang $id',
  'satuan': 'kg',
  'stok_minimum': '1',
  'status_aktif': 1,
  'nama_jenis': 'Pupuk',
  'nama_obat': null,
};
