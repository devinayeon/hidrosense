import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/sync_queue_item.dart';

/// Antrean tulis yang bertahan di perangkat sampai berhasil dikirim.
///
/// Berbeda dari `InventoryCache` yang sengaja hanya-baca, tabel ini menyimpan
/// perubahan yang belum sampai ke server supaya tidak hilang saat aplikasi
/// ditutup. Pola buka/injeksi basis datanya mengikuti `SessionStore` supaya
/// pengujian bisa memakai `databaseFactoryFfi`.
final class SyncQueueStore {
  SyncQueueStore(this._db);
  final Database _db;

  static const _filename = 'sync_queue.db';

  /// `null` kalau basis data tidak tersedia (mis. pengujian tanpa plugin).
  /// Pemanggil harus menganggapnya sebagai "antrean kosong".
  static Future<SyncQueueStore?> open() async {
    try {
      return SyncQueueStore(
        await openDatabase(
          path.join(await getDatabasesPath(), _filename),
          version: 1,
          onCreate: createSchema,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> createSchema(Database db, int version) async {
    await db.execute('''CREATE TABLE sync_queue (
      server_origin TEXT NOT NULL,
      user_id TEXT NOT NULL,
      key TEXT NOT NULL,
      jenis TEXT NOT NULL,
      subtitle TEXT NOT NULL,
      target TEXT NOT NULL,
      payload TEXT NOT NULL,
      created_at TEXT NOT NULL,
      PRIMARY KEY(server_origin, user_id, key))''');
  }

  /// Menyimpan (atau memperbarui) satu baris; kunci yang sama menimpa baris
  /// lama supaya kiriman ulang tidak menumpuk.
  Future<void> enqueue({
    required String serverOrigin,
    required String userId,
    required SyncQueueItem item,
  }) async {
    try {
      await _db.insert('sync_queue', {
        'server_origin': serverOrigin,
        'user_id': userId,
        ...item.toJson(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {
      // Antrean tetap jalan di memori; gagal menyimpan bukan alasan menggagalkan
      // penulisan penjualan.
    }
  }

  /// Baris paling lama di depan, supaya urutan kirim mengikuti urutan catat.
  Future<List<SyncQueueItem>> list({
    required String serverOrigin,
    required String userId,
  }) async {
    try {
      final rows = await _db.query(
        'sync_queue',
        where: 'server_origin=? AND user_id=?',
        whereArgs: [serverOrigin, userId],
        orderBy: 'created_at, key',
      );
      final items = <SyncQueueItem>[];
      for (final row in rows) {
        final item = SyncQueueItem.fromJson(row);
        if (item != null) items.add(item);
      }
      return items;
    } catch (_) {
      return const [];
    }
  }

  Future<void> remove({
    required String serverOrigin,
    required String userId,
    required String key,
  }) async {
    try {
      await _db.delete(
        'sync_queue',
        where: 'server_origin=? AND user_id=? AND key=?',
        whereArgs: [serverOrigin, userId, key],
      );
    } catch (_) {
      // Tidak ada yang bisa dilakukan kalau baris tidak terbaca.
    }
  }

  Future<void> close() => _db.close();
}
