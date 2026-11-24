import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

/// Status "sudah dibaca" notifikasi in-app, tersimpan di perangkat.
///
/// Notifikasi dibangun ulang dari data tiap kali Beranda dibuka, jadi status
/// bacanya disimpan terpisah dengan kunci stabil (id notifikasi) per pengguna
/// dan per alamat layanan (D-23). Tanpa plugin basis data, halaman tetap jalan
/// dengan status di memori.
final class NotificationReadStore {
  NotificationReadStore(this._db);
  final Database _db;

  static const _filename = 'notification_read.db';
  static const _version = 1;

  /// `null` kalau basis data tidak tersedia (mis. pengujian tanpa plugin).
  /// Pemanggil harus menganggapnya sebagai "belum ada yang dibaca".
  static Future<NotificationReadStore?> open() async {
    try {
      return NotificationReadStore(
        await openDatabase(
          path.join(await getDatabasesPath(), _filename),
          version: _version,
          onCreate: createSchema,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> createSchema(Database db, int version) async {
    await db.execute('''CREATE TABLE notification_read (
      server_origin TEXT NOT NULL,
      user_id TEXT NOT NULL,
      notif_id TEXT NOT NULL,
      read_at TEXT NOT NULL,
      PRIMARY KEY(server_origin, user_id, notif_id))''');
  }

  /// Id notifikasi yang sudah dibaca pengguna ini; kosong kalau gagal membaca.
  Future<Set<String>> readIds({
    required String serverOrigin,
    required String userId,
  }) async {
    try {
      final rows = await _db.query(
        'notification_read',
        columns: ['notif_id'],
        where: 'server_origin=? AND user_id=?',
        whereArgs: [serverOrigin, userId],
      );
      return {
        for (final row in rows) row['notif_id']! as String,
      };
    } catch (_) {
      return const {};
    }
  }

  /// Menandai satu notifikasi sudah dibaca; id yang sama menimpa baris lama.
  Future<void> markRead({
    required String serverOrigin,
    required String userId,
    required String notifId,
    required DateTime readAt,
  }) async {
    try {
      await _db.insert('notification_read', {
        'server_origin': serverOrigin,
        'user_id': userId,
        'notif_id': notifId,
        'read_at': readAt.toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {
      // Status tetap hidup di memori; kegagalan menyimpan bukan alasan melempar.
    }
  }

  Future<void> close() => _db.close();
}
