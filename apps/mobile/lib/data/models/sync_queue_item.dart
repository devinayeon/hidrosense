/// Jenis data yang ikut disinkronkan; menentukan ikon baris di halaman 11.
enum SyncQueueJenis { semaian, stok, panen, penjualan, rusak }

/// Satu tulis yang tersimpan di HP dan menunggu dikirim ke server.
///
/// Kunci idempoten ([key]) dipakai sebagai identitas baris: kiriman ulang
/// memakai kunci yang sama, jadi tidak akan tercatat dua kali di server.
class SyncQueueItem {
  const SyncQueueItem({
    required this.key,
    required this.jenis,
    required this.subtitle,
    required this.target,
    required this.payload,
    required this.createdAt,
  });

  /// Kunci idempoten kiriman (lihat `SaleCommand.key`).
  final String key;
  final SyncQueueJenis jenis;

  /// Baris kedua di UI, mis. nama pembeli.
  final String subtitle;

  /// `create` untuk penjualan baru, atau id baris untuk koreksi.
  final String target;

  /// Isi kiriman yang disimpan apa adanya untuk dikirim ulang.
  final String payload;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'key': key,
    'jenis': jenis.name,
    'subtitle': subtitle,
    'target': target,
    'payload': payload,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  /// `null` kalau baris rusak; pemanggil melewatinya.
  static SyncQueueItem? fromJson(Map<String, Object?> row) {
    final key = row['key'];
    final jenis = row['jenis'];
    final subtitle = row['subtitle'];
    final target = row['target'];
    final payload = row['payload'];
    final createdAt = DateTime.tryParse(row['created_at'] as String? ?? '');
    if (key is! String ||
        subtitle is! String ||
        target is! String ||
        payload is! String ||
        createdAt == null) {
      return null;
    }
    final parsed = SyncQueueJenis.values
        .where((value) => value.name == jenis)
        .firstOrNull;
    if (parsed == null) return null;
    return SyncQueueItem(
      key: key,
      jenis: parsed,
      subtitle: subtitle,
      target: target,
      payload: payload,
      createdAt: createdAt.toUtc(),
    );
  }
}
