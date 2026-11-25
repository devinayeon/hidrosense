import '../../core/uuid.dart';
import '../services/api_client.dart';
import '../services/local_kv_store.dart';

/// Kapan perangkat ini terakhir selesai sinkron.
///
/// Jam disimpan di dua tempat supaya tidak lagi kembali ke angka contoh saat
/// pengguna keluar dari menu Sinkron: di HP (langsung tersedia, juga tanpa
/// internet) dan di server (bertahan walau aplikasi dipasang ulang atau
/// datanya dibersihkan). Yang dipakai selalu yang paling baru dari keduanya.
class SyncStatusRepository {
  SyncStatusRepository(
    this._api,
    this._store, {
    required this.userId,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ApiClient _api;
  final Future<LocalKvStore?> Function() _store;
  final String userId;
  final DateTime Function() _clock;

  static const _lastSyncKey = 'last_synced_at';
  static const _deviceKey = 'device_id';

  /// Satu cakupan per server dan pengguna; perangkat yang sama dengan akun
  /// berbeda tidak berbagi jam.
  String get _scope => '${_api.serverOrigin}|$userId';

  /// Pengenal perangkat ini, dibuat sekali lalu dipakai selamanya. Server
  /// memakainya untuk memisahkan jam sinkron antar-HP milik satu akun.
  Future<String> deviceId() async {
    final store = await _store();
    final saved = await store?.get(_scope, _deviceKey);
    if (saved != null) return saved;
    final created = generateUuidV4();
    await store?.set(_scope, _deviceKey, created);
    return created;
  }

  /// Jam tersimpan di HP; `null` kalau belum pernah sinkron di sini.
  Future<DateTime?> readLocal() async {
    final raw = await (await _store())?.get(_scope, _lastSyncKey);
    return raw == null ? null : DateTime.tryParse(raw)?.toUtc();
  }

  Future<void> _saveLocal(DateTime time) async {
    await (await _store())?.set(
      _scope,
      _lastSyncKey,
      time.toUtc().toIso8601String(),
    );
  }

  static DateTime? _newest(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  /// Menyegarkan dari server dan mengembalikan jam terbaru. Tanpa internet
  /// yang dikembalikan jam di HP, jadi layar tetap menampilkan angka asli.
  Future<DateTime?> refresh() async {
    final local = await readLocal();
    try {
      final device = await deviceId();
      final response = await _api.get(
        'sync/status',
        query: {'device_id': device},
      );
      final remote = _parse(response);
      final newest = _newest(local, remote);
      if (newest != null && newest != local) await _saveLocal(newest);
      return newest;
    } catch (_) {
      return local;
    }
  }

  /// Mencatat satu sinkron yang baru selesai dan mengembalikan jamnya.
  ///
  /// Jam diambil dari server karena itu yang tersimpan di sana. Kalau server
  /// tidak terjangkau, hasilnya tergantung [trustLocal]: `true` (data baru
  /// saja terkirim jadi sinkronnya nyata) memakai jam HP, `false` (tidak ada
  /// bukti sambungan, mis. antrean kosong) melempar galatnya supaya layar
  /// tidak mengaku sudah sinkron.
  Future<DateTime> markSynced({bool trustLocal = false}) async {
    try {
      final device = await deviceId();
      final response = await _api.post(
        'sync/status',
        body: {'device_id': device},
      );
      final stamped = _parse(response);
      if (stamped == null) {
        throw const FormatException('Jam sinkron dari layanan tidak valid.');
      }
      final newest = _newest(await readLocal(), stamped)!;
      await _saveLocal(newest);
      return newest;
    } catch (_) {
      if (!trustLocal) rethrow;
      final now = _clock().toUtc();
      final newest = _newest(await readLocal(), now)!;
      await _saveLocal(newest);
      return newest;
    }
  }

  static DateTime? _parse(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Respons sinkron tidak valid.');
    }
    final raw = data['last_synced_at'];
    if (raw == null) return null;
    if (raw is! String) {
      throw const FormatException('Respons sinkron tidak valid.');
    }
    return DateTime.tryParse(raw)?.toUtc();
  }
}
