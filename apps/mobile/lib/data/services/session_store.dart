import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'api_client.dart';

/// Sesi yang disimpan di perangkat supaya pengguna tidak perlu login ulang.
///
/// Masa berlakunya berasal dari layanan: `refresh_expires_at` bertambah 7 hari
/// setiap refresh dan tidak pernah lebih dari 30 hari sejak login. Sesi tanpa
/// tanggal kedaluwarsa dianggap tidak layak dipakai (gagal tertutup).
final class StoredSession {
  StoredSession({
    required this.accessToken,
    required this.refreshToken,
    required this.refreshExpiresAt,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime refreshExpiresAt;
  final SessionUser user;

  bool get expired => !refreshExpiresAt.isAfter(DateTime.now().toUtc());
}

/// Satu baris sesi per alamat layanan.
///
/// Pola buka/injeksi basis datanya mengikuti `InventoryCache` supaya pengujian
/// bisa memakai `databaseFactoryFfi`.
final class SessionStore {
  SessionStore(this._db);
  final Database _db;

  static const _filename = 'session.db';

  /// `null` kalau basis data tidak tersedia (mis. pengujian tanpa plugin).
  /// Pemanggil harus menganggapnya sebagai "tidak ada sesi tersimpan".
  static Future<SessionStore?> open() async {
    try {
      return SessionStore(
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
    await db.execute('''CREATE TABLE sessions (
      server_origin TEXT PRIMARY KEY NOT NULL,
      access_token TEXT NOT NULL,
      refresh_token TEXT NOT NULL,
      refresh_expires_at TEXT NOT NULL,
      user_payload TEXT NOT NULL,
      saved_at TEXT NOT NULL)''');
  }

  Future<void> save({
    required String serverOrigin,
    required StoredSession session,
  }) async {
    try {
      await _db.insert('sessions', {
        'server_origin': serverOrigin,
        'access_token': session.accessToken,
        'refresh_token': session.refreshToken,
        'refresh_expires_at': session.refreshExpiresAt
            .toUtc()
            .toIso8601String(),
        'user_payload': jsonEncode(session.user.toJson()),
        'saved_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {
      // Sesi tetap berjalan di memori; gagal menyimpan bukan alasan keluar.
    }
  }

  Future<StoredSession?> read({required String serverOrigin}) async {
    try {
      final rows = await _db.query(
        'sessions',
        where: 'server_origin=?',
        whereArgs: [serverOrigin],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final row = rows.first;
      final expiry = DateTime.tryParse(
        row['refresh_expires_at'] as String? ?? '',
      );
      final payload = jsonDecode(row['user_payload'] as String? ?? '');
      if (expiry == null || payload is! Map<String, dynamic>) {
        await clear(serverOrigin: serverOrigin);
        return null;
      }
      return StoredSession(
        accessToken: row['access_token'] as String,
        refreshToken: row['refresh_token'] as String,
        refreshExpiresAt: expiry.toUtc(),
        user: SessionUser.fromJson(payload),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clear({required String serverOrigin}) async {
    try {
      await _db.delete(
        'sessions',
        where: 'server_origin=?',
        whereArgs: [serverOrigin],
      );
    } catch (_) {
      // Tidak ada yang bisa dilakukan kalau baris sesi tidak terbaca.
    }
  }
}
