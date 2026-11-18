/// Ilustrasi khusus alur "04 Inventaris".
///
/// Dua PNG diekspor dari node `Illustration/inventory-stock` (frame 4.5),
/// `Illustration/no-search-results` (frame 4.6), dan `Illustration/
/// offline-no-internet` (frame 4.4, dipakai bersama alur lain) supaya bentuknya
/// tetap sama dengan desain.
abstract final class V2InventarisAssets {
  static const String _base = 'lib/views/v2/assets/illustrations';

  /// Frame `4.4 Gagal memuat stok`.
  static const String offlineNoInternet = '$_base/offline-no-internet.png';

  /// Frame `4.5 Stok kosong`.
  static const String inventoryStock = '$_base/inventory-stock.png';

  /// Frame `4.6 Cari tanpa hasil`.
  static const String noSearchResults = '$_base/no-search-results.png';
}
