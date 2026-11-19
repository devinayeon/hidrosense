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
  static const _version = 2;

  /// `null` kalau basis data tidak tersedia (mis. pengujian tanpa plugin).
  /// Pemanggil harus menganggapnya sebagai "antrean kosong".
  static Future<SyncQueueStore?> open() async {
    try {
      return SyncQueueStore(
        await openDatabase(
          path.join(await getDatabasesPath(), _filename),
          version: _version,
          onCreate: createSchema,
          onUpgrade: upgradeSchema,
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
      mode TEXT NOT NULL,
      target TEXT NOT NULL,
      payload TEXT NOT NULL,
      expected_version TEXT,
      status TEXT NOT NULL,
      error TEXT,
      created_at TEXT NOT NULL,
      PRIMARY KEY(server_origin, user_id, key))''');
  }

  /// Versi 1 belum menyimpan mode/versi/keadaan tulis, jadi baris lama diisi
  /// nilai yang membuatnya diperlakukan sebagai penjualan baru.
  static Future<void> upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE sync_queue ADD COLUMN mode TEXT NOT NULL DEFAULT 'baru'",
      );
      await db.execute('ALTER TABLE sync_queue ADD COLUMN expected_version TEXT');
      await db.execute(
        "ALTER TABLE sync_queue ADD COLUMN status TEXT NOT NULL DEFAULT 'antrean'",
      );
      await db.execute('ALTER TABLE sync_queue ADD COLUMN error TEXT');
    }
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

  /// Menandai satu baris ditolak server; tetap di antrean untuk diperbaiki.
  Future<void> markFailed({
    required String serverOrigin,
    required String userId,
    required String key,
    required String error,
  }) => _mark(
    serverOrigin: serverOrigin,
    userId: userId,
    key: key,
    status: SyncQueueStatus.gagal,
    error: error,
  );

  /// Menandai satu baris bentrok versi (dialog 11.8).
  Future<void> markConflict({
    required String serverOrigin,
    required String userId,
    required String key,
    required String error,
  }) => _mark(
    serverOrigin: serverOrigin,
    userId: userId,
    key: key,
    status: SyncQueueStatus.konflik,
    error: error,
  );

  Future<void> _mark({
    required String serverOrigin,
    required String userId,
    required String key,
    required SyncQueueStatus status,
    required String error,
  }) async {
    try {
      await _db.update(
        'sync_queue',
        {'status': status.name, 'error': error},
        where: 'server_origin=? AND user_id=? AND key=?',
        whereArgs: [serverOrigin, userId, key],
      );
    } catch (_) {
      // Sama seperti enqueue: kegagalan menandai tidak boleh melempar.
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
