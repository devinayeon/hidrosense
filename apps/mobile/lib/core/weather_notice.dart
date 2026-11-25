import '../models/weather_model.dart';

/// Isi satu notifikasi saran cuaca. Tidak disimpan di mana pun: hanya dikirim ke sistem.
class WeatherNotice {
  const WeatherNotice({
    required this.id,
    required this.title,
    required this.body,
  });

  /// Satu id per tanggal (yyyymmdd), sehingga notifikasi hari yang sama menimpa, bukan menumpuk.
  final int id;
  final String title;
  final String body;
}

/// Notifikasi dari prakiraan hari ini, atau null bila tidak ada tindakan yang dipicu cuaca.
///
/// Hanya tindakan dengan derajat fuzzy yang dikirim; "Lanjutkan Perawatan Rutin" tidak layak
/// mengganggu pengguna. Kalimat penutup mengingatkan bahwa saran ini boleh diabaikan.
WeatherNotice? buildWeatherNotice(PrakiraanHarian today, DateTime localDate) {
  final triggered =
      today.rekomendasiList.where((a) => a.derajat != null).toList()
        ..sort((a, b) => b.derajat!.compareTo(a.derajat!));
  if (triggered.isEmpty) return null;
  final important = triggered.where((a) => a.isPenting).length;
  final top = triggered.take(2).map((a) => a.judul).join(' · ');
  final more = triggered.length > 2
      ? ' dan ${triggered.length - 2} saran lain'
      : '';
  return WeatherNotice(
    id: localDate.year * 10000 + localDate.month * 100 + localDate.day,
    title: important > 0
        ? 'Saran cuaca hari ini: $important penting'
        : 'Saran cuaca hari ini',
    body: '$top$more. Keputusan tetap di tangan Anda.',
  );
}
