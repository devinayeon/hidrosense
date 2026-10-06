import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/inventory_record.dart';
import 'package:hidrosense_mobile/data/services/inventory_cache.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

InventoryRecord item(String id) => InventoryRecord.fromJson({
  'id_inventaris': id,
  'public_id': null,
  'version': null,
  'id_jenis_inventaris': '2',
  'id_obat': null,
  'nama_barang': 'Benih',
  'satuan': 'gram',
  'stok_minimum': null,
  'status_aktif': 1,
  'nama_jenis': 'Bibit',
  'nama_obat': null,
  'saldo': '0.01',
});

void main() {
  sqfliteFfiInit();
  test(
    'disk snapshot reopens, isolates server/user and rolls back partial replacement',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'inventory_cache_test_',
      );
      final filename = path.join(directory.path, 'cache.db');
      Future<InventoryCache> open() async => InventoryCache(
        await databaseFactoryFfi.openDatabase(
          filename,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: InventoryCache.createSchema,
          ),
        ),
      );
      var cache = await open();
      addTearDown(() async {
        await cache.close();
        await directory.delete(recursive: true);
      });
      final first = DateTime.utc(2026, 10, 6);
      await cache.replace(
        serverOrigin: 'https://one.test',
        userId: '1',
        records: [item('9223372036854775807')],
        fetchedAt: first,
      );
      await cache.replace(
        serverOrigin: 'https://one.test',
        userId: '2',
        records: [item('2')],
        fetchedAt: first,
      );
      await cache.replace(
        serverOrigin: 'https://two.test',
        userId: '1',
        records: [item('3')],
        fetchedAt: first,
      );
      await cache.close();
      cache = await open();
      final restored = (await cache.read(
        serverOrigin: 'https://one.test',
        userId: '1',
      ))!;
      expect(restored.records.single.id, '9223372036854775807');
      expect(restored.records.single.balance, '0.01');
      expect(restored.fetchedAt, first);
      expect(() => restored.records.clear(), throwsUnsupportedError);
      expect(
        (await cache.read(
          serverOrigin: 'https://one.test',
          userId: '2',
        ))!.records.single.id,
        '2',
      );
      expect(
        (await cache.read(
          serverOrigin: 'https://two.test',
          userId: '1',
        ))!.records.single.id,
        '3',
      );
      expect(
        await cache.read(serverOrigin: 'https://one.test', userId: 'missing'),
        isNull,
      );
      await expectLater(
        cache.replace(
          serverOrigin: 'https://one.test',
          userId: '1',
          records: [item('4'), item('4')],
          fetchedAt: first.add(const Duration(days: 1)),
        ),
        throwsA(isA<DatabaseException>()),
      );
      final preserved = (await cache.read(
        serverOrigin: 'https://one.test',
        userId: '1',
      ))!;
      expect(preserved.records.single.id, '9223372036854775807');
      expect(preserved.fetchedAt, first);
      await cache.replace(
        serverOrigin: 'https://one.test',
        userId: '1',
        records: [],
        fetchedAt: first,
      );
      expect(
        (await cache.read(
          serverOrigin: 'https://one.test',
          userId: '1',
        ))!.records,
        isEmpty,
      );
      expect(
        (await cache.read(
          serverOrigin: 'https://one.test',
          userId: '2',
        ))!.records.single.id,
        '2',
      );
    },
  );
}
