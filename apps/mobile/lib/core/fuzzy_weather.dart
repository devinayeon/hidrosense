/// Logika fuzzy untuk rekomendasi tindakan dari cuaca BMKG.
///
/// Setiap parameter cuaca diubah menjadi derajat keanggotaan 0..1, bukan ambang keras. Titik 0,5
/// sengaja dipasang tepat di ambang lama (suhu 32°C, kelembapan 85%, hujan 0,5 mm, angin 20 km/jam),
/// sehingga perilaku di sekitar ambang tetap dikenali pengguna sementara transisinya halus.
///
/// Aturan "tekanan hama" adalah POLA dummy (hama pengisap berkembang pada cuaca hangat dan kering),
/// belum berbasis data lapangan. Tindakan akhir selalu keputusan pengguna dan hanya berupa notifikasi.
library;

/// Naik linear dari 0 di [a] ke 1 di [b]; di luar rentang tertahan di 0 atau 1.
double ramp(num x, num a, num b) {
  if (x <= a) return 0;
  if (x >= b) return 1;
  return (x - a) / (b - a);
}

/// Naik di [a]..[b], datar 1 di [b]..[c], turun di [c]..[d].
double trapezoid(num x, num a, num b, num c, num d) {
  if (x <= a || x >= d) return 0;
  if (x < b) return (x - a) / (b - a);
  if (x <= c) return 1;
  return (d - x) / (d - c);
}

/// Derajat keanggotaan hasil fuzzifikasi satu prakiraan harian.
class FuzzyWeather {
  const FuzzyWeather({
    required this.hot,
    required this.warm,
    required this.humid,
    required this.rain,
    required this.windy,
    required this.fungal,
    required this.pestPressure,
  });

  /// Panas (stres suhu larutan). 0,5 pada 32°C.
  final double hot;

  /// Hangat (perlu dipantau). 0,5 pada sekitar 29,5°C, datar 1 pada 31..34°C.
  final double warm;

  /// Lembap tinggi (risiko jamur daun). 0,5 pada 85%.
  final double humid;

  /// Hujan. 1 bila teks BMKG menyebut hujan, atau 0,5 pada 0,5 mm.
  final double rain;

  /// Angin kencang. 0,5 pada 20 km/jam.
  final double windy;

  /// Risiko jamur daun: lembap tinggi, ATAU (cukup lembap DAN hujan).
  final double fungal;

  /// Tekanan hama dari cuaca: (hangat ATAU panas) DAN kering.
  final double pestPressure;
}

FuzzyWeather fuzzifyWeather({
  required int maxTemperature,
  required int maxHumidity,
  required double totalRainfallMm,
  required int maxWindSpeed,
  required bool hasRainText,
}) {
  final hot = ramp(maxTemperature, 30, 34);
  final warm = trapezoid(maxTemperature, 28, 31, 34, 36);
  final rain = hasRainText ? 1.0 : ramp(totalRainfallMm, 0, 1);
  final humid = ramp(maxHumidity, 75, 95);
  final dampAndRain = _and(ramp(maxHumidity, 65, 85), rain);
  return FuzzyWeather(
    hot: hot,
    warm: warm,
    humid: humid,
    rain: rain,
    windy: ramp(maxWindSpeed, 10, 30),
    fungal: _or(humid, dampAndRain),
    pestPressure: _and(_or(hot, warm), 1 - rain),
  );
}

/// Operator fuzzy Zadeh: DAN = minimum, ATAU = maksimum.
double _and(double a, double b) => a < b ? a : b;
double _or(double a, double b) => a > b ? a : b;

/// Derajat ≥ ini menjadi tindakan "Penting"; di bawahnya "Rutin".
const double kImportantDegree = 0.7;

/// Derajat ≥ ini baru dianggap relevan untuk ditampilkan.
const double kRelevantDegree = 0.5;
