/// Path aset ilustrasi page “09 Perawatan & Hama”.
///
/// `item-plant-care.png` diekspor 3× (480 px) dari node
/// `Illustration/item-plant-care` (frame 9.5). PNG-nya transparan; latar biru
/// muda pada kartu “Cek hama” digambar oleh widget.
library;

abstract final class V2RawatAssets {
  static const String _base = 'lib/views/v2/assets/illustrations';

  static const String itemPlantCare = '$_base/item-plant-care.png';

  /// Ilustrasi tanpa internet dipakai bersama page 04–08.
  static const String offlineNoInternet = '$_base/offline-no-internet.png';

  /// Foto contoh di kartu “Foto tanaman” (frame 9.9).
  static const String harvestLettuce = '$_base/harvest-lettuce.png';
}