import 'v2_penjualan_data.dart';

/// Isian form penjualan sebelum dikirim ke backend.
class V2PenjualanDraft {
  const V2PenjualanDraft({
    required this.tanggal,
    required this.pembeli,
    required this.panenId,
    required this.jumlahKg,
    required this.hargaPerKg,
    required this.pembayaran,
  });

  final DateTime tanggal;
  final String pembeli;
  final String? panenId;
  final double jumlahKg;
  final double hargaPerKg;
  final V2PenjualanBayar pembayaran;
}

/// Data yang dimuat sekali saat daftar penjualan dibuka.
class V2PenjualanSnapshot {
  const V2PenjualanSnapshot({required this.items, required this.panen});

  final List<V2Penjualan> items;

  /// Pilihan sheet "Pilih panen" untuk form catat penjualan.
  final List<V2PenjualanPanen> panen;
}

/// Jembatan alur "08 Penjualan" ke backend.
///
/// Kalau store tidak diberikan (galeri/pratinjau), halaman memakai data contoh
/// [designPenjualan] dan mengubahnya di memori saja.
abstract interface class V2PenjualanStore {
  Future<V2PenjualanSnapshot> load();

  Future<V2Penjualan> create(V2PenjualanDraft draft);

  Future<V2Penjualan> update(V2Penjualan existing, V2PenjualanDraft draft);

  Future<V2Penjualan> markPaid(V2Penjualan existing);

  /// Mengambil ulang satu penjualan dari server — dipakai tombol "Muat ulang"
  /// pada dialog konflik versi (frame 8.24).
  Future<V2Penjualan> reload(V2Penjualan existing);
}

/// Galat store yang pesannya sudah siap ditampilkan ke pengguna.
class V2PenjualanStoreException implements Exception {
  const V2PenjualanStoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Konflik versi: baris sudah diubah perangkat lain sejak terakhir dibaca.
///
/// Dipisahkan dari [V2PenjualanStoreException] supaya formulir bisa membuka
/// dialog "Data sudah berubah" (8.24), bukan sekadar menampilkan snackbar.
class V2PenjualanConflictException extends V2PenjualanStoreException {
  const V2PenjualanConflictException([
    super.message = 'Data sudah berubah di server. Muat ulang versi terbaru.',
  ]);
}
