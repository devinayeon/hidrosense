/// Ilustrasi khusus alur "05 Semaian".
///
/// Tiga PNG: `Illustration/nursery-seedlings` (frame 5.5),
/// `Illustration/offline-no-internet` (frame 5.4, dipakai bersama alur lain),
/// dan `Illustration/nft-growing-table` (frame 5.18/5.20/5.22).
abstract final class V2SemaianAssets {
  static const String _base = 'lib/views/v2/assets/illustrations';

  /// Frame `5.5 Semaian kosong`.
  static const String nurserySeedlings = '$_base/nursery-seedlings.png';

  /// Frame `5.4 Gagal memuat semaian`.
  static const String offlineNoInternet = '$_base/offline-no-internet.png';

  /// Frame `5.18/5.20/5.22 Hasil pindah`: node `Illustration/nft-growing-table`,
  /// diekspor 3x dari FigCraft (480 px) supaya tajam di layar padat.
  static const String growingTable = '$_base/growing-table.png';
}
