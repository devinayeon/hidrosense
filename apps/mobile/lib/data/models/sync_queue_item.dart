/// Jenis data yang ikut disinkronkan; menentukan ikon baris di halaman 11.
///
/// Urutan deklarasi sekaligus urutan kirim: induk lebih dulu (semaian, lalu
/// stok dan panen), baru penjualan dan rusak yang bergantung padanya.
enum SyncQueueJenis { semaian, stok, panen, penjualan, rusak }

/// Bagian penjualan yang ditulis, menentukan cara mengirim ulang.
enum SyncQueueMode {
  /// Penjualan baru: `POST penjualan`.
  baru,

  /// Ubah jumlah/harga/panen: `PATCH penjualan/{id}` dengan rincian.
  rincian,

  /// Ubah header (pembeli/tanggal/status): `PATCH penjualan/{id}`.
  header,
}

/// Keadaan satu baris antrean.
enum SyncQueueStatus {
  /// Masih menunggu dikirim (atau kiriman terakhir tidak pasti).
  antrean,

  /// Ditolak server; perlu diperbaiki atau menunggu tindakan pengguna.
  gagal,

  /// Bentrok versi: baris di server berubah setelah data ini diubah di HP.
  /// Pengguna memilih versi di dialog 11.8.
  konflik,
}

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
    this.mode = SyncQueueMode.baru,
    this.expectedVersion,
    this.status = SyncQueueStatus.antrean,
    this.error,
  });

  /// Kunci idempoten kiriman (lihat `SaleCommand.key`).
  final String key;
  final SyncQueueJenis jenis;

  /// Baris kedua di UI, mis. nama pembeli.
  final String subtitle;

  /// Bagian penjualan yang ditulis.
  final SyncQueueMode mode;

  /// `create` untuk penjualan baru, atau id baris untuk koreksi.
  final String target;

  /// Isi kiriman yang disimpan apa adanya untuk dikirim ulang.
  final String payload;

  /// Versi baris sebelum dikoreksi; null untuk penjualan baru.
  final String? expectedVersion;

  /// Keadaan baris; `gagal` setelah server menolak dengan pasti.
  final SyncQueueStatus status;

  /// Pesan penolakan terakhir, bila [status] `gagal`.
  final String? error;
  final DateTime createdAt;

  SyncQueueItem copyWith({SyncQueueStatus? status, String? error}) =>
      SyncQueueItem(
        key: key,
        jenis: jenis,
        subtitle: subtitle,
        mode: mode,
        target: target,
        payload: payload,
        expectedVersion: expectedVersion,
        status: status ?? this.status,
        error: error ?? this.error,
        createdAt: createdAt,
      );

  Map<String, Object?> toJson() => {
    'key': key,
    'jenis': jenis.name,
    'subtitle': subtitle,
    'mode': mode.name,
    'target': target,
    'payload': payload,
    'expected_version': expectedVersion,
    'status': status.name,
    'error': error,
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
    final parsedJenis = _parse(SyncQueueJenis.values, jenis);
    final parsedMode = _parse(SyncQueueMode.values, row['mode']);
    final parsedStatus = _parse(SyncQueueStatus.values, row['status']);
    if (parsedJenis == null || parsedMode == null || parsedStatus == null) {
      return null;
    }
    return SyncQueueItem(
      key: key,
      jenis: parsedJenis,
      subtitle: subtitle,
      mode: parsedMode,
      target: target,
      payload: payload,
      expectedVersion: row['expected_version'] as String?,
      status: parsedStatus,
      error: row['error'] as String?,
      createdAt: createdAt.toUtc(),
    );
  }

  static T? _parse<T extends Enum>(List<T> values, Object? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }
}
