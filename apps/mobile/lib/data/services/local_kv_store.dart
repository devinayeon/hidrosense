import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

/// Penyimpanan kunci-nilai kecil yang bertahan di perangkat.
///
/// Dipakai untuk hal ringan yang harus selamat dari tutup-buka aplikasi,
/// misalnya jam sinkron terakhir dan lokasi cuaca pilihan. Tiap pasangan
/// dipisah per [scope] (server dan pengguna) supaya akun yang berbeda di HP
/// yang sama tidak saling membaca. Pola buka/injeksi basis datanya mengikuti
/// `SyncQueueStore` supaya pengujian bisa memakai `databaseFactoryFfi`.
final class LocalKvStore {
  LocalKvStore(this._db);
  final Database _db;

  static const _filename = 'local_kv.db';
  static const _version = 1;

  /// `null` kalau basis data tidak tersedia (mis. pengujian tanpa plugin).
  /// Pemanggil harus menganggapnya sebagai "belum ada yang tersimpan".
  static Future<LocalKvStore?> open() async {
    try {
      return LocalKvStore(
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
    await db.execute('''CREATE TABLE kv (
      scope TEXT NOT NULL,
      key TEXT NOT NULL,
      value TEXT NOT NULL,
      PRIMARY KEY(scope, key))''');
  }

  Future<String?> get(String scope, String key) async {
    final rows = await _db.query(
      'kv',
      columns: ['value'],
      where: 'scope = ? AND key = ?',
      whereArgs: [scope, key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> set(String scope, String key, String value) => _db.insert('kv', {
    'scope': scope,
    'key': key,
    'value': value,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> remove(String scope, String key) =>
      _db.delete('kv', where: 'scope = ? AND key = ?', whereArgs: [scope, key]);

  Future<void> close() => _db.close();
}
