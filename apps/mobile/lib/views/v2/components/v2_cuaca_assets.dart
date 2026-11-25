/// Path aset ilustrasi page “10 Cuaca BMKG”.
///
/// `weather-greenhouse.png` diekspor 3× (288 px) dari node
/// `Illustration/weather-greenhouse` (frame 10.1). PNG-nya transparan; kartu
/// putih “Sekarang” digambar oleh widget.
library;

abstract final class V2CuacaAssets {
  static const String _base = 'lib/views/v2/assets/illustrations';

  static const String weatherGreenhouse = '$_base/weather-greenhouse.png';

  /// Ilustrasi tanpa internet dipakai bersama page 04–09.
  static const String offlineNoInternet = '$_base/offline-no-internet.png';
}
