import 'formatting.dart';
import '../models/weather_model.dart';

class WeatherRuleEvaluation {
  const WeatherRuleEvaluation({required this.summary, required this.actions});

  final String summary;
  final List<TindakanRekomendasi> actions;
}

/// Mencocokkan parameter cuaca BMKG dengan aturan perawatan HidroSense.
///
/// Aturan hanya memakai nilai yang benar-benar tersedia dari respons BMKG.
/// Hasilnya dipakai untuk mengisi ringkasan dan daftar tindakan pada halaman
/// rekomendasi cuaca.
WeatherRuleEvaluation evaluateWeatherRules({
  required int maxTemperature,
  required int maxHumidity,
  required double totalRainfallMm,
  required int maxWindSpeed,
  required Iterable<String> weatherDescriptions,
}) {
  final descriptions = weatherDescriptions
      .map((description) => description.toLowerCase())
      .toList(growable: false);
  final hasRain =
      descriptions.any((description) => description.contains('hujan')) ||
      totalRainfallMm >= 0.5;

  final actions = <TindakanRekomendasi>[];
  final highlights = <String>[];

  if (maxTemperature > 32) {
    actions.add(
      const TindakanRekomendasi(
        judul: 'Atur Debit Nutrisi Meja NFT',
        deskripsi:
            'Tingkatkan sirkulasi dan debit aliran agar suhu larutan tetap stabil. Cek EC dan pH pada pagi atau sore hari.',
        alasan: 'Prakiraan suhu melewati ambang 32°C.',
        labelTag: 'Penting',
        isPenting: true,
      ),
    );
    highlights.add('suhu panas hingga $maxTemperature°C');
  } else if (maxTemperature >= 30) {
    actions.add(
      const TindakanRekomendasi(
        judul: 'Pantau Suhu Larutan',
        deskripsi:
            'Catat suhu tandon dan pastikan pompa bekerja stabil saat suhu siang meningkat.',
        alasan: 'Suhu siang diprakirakan cukup hangat.',
        labelTag: 'Rutin',
      ),
    );
    highlights.add('suhu siang hingga $maxTemperature°C');
  }

  if (hasRain) {
    final rainDescription = descriptions.firstWhere(
      (description) => description.contains('hujan'),
      orElse: () => 'hujan',
    );
    actions.add(
      TindakanRekomendasi(
        judul: 'Lindungi Instalasi & Sesuaikan Nutrisi',
        deskripsi:
            'Tutup tandon, pastikan drainase lancar, dan jaga EC larutan pada 1.2–1.4 mS/cm agar tidak terdilusi air hujan.',
        alasan:
            'BMKG memprakirakan $rainDescription dengan akumulasi ${formatAngka(totalRainfallMm)} mm.',
        labelTag: 'Penting',
        isPenting: true,
      ),
    );
    highlights.add('peluang hujan ${formatAngka(totalRainfallMm)} mm');
  }

  if (maxHumidity >= 85) {
    actions.add(
      TindakanRekomendasi(
        judul: 'Waspadai Jamur Daun',
        deskripsi:
            'Lakukan inspeksi daun dan atur ventilasi greenhouse. Semprot pencegahan hanya bila gejala jamur terlihat.',
        alasan: 'Kelembapan udara mencapai $maxHumidity%.',
        labelTag: 'Penting',
        isPenting: true,
      ),
    );
    highlights.add('kelembapan tinggi hingga $maxHumidity%');
  }

  if (maxWindSpeed >= 20) {
    actions.add(
      TindakanRekomendasi(
        judul: 'Periksa Rangka & Naungan',
        deskripsi:
            'Pastikan rangka meja, naungan, dan penutup greenhouse terpasang kokoh.',
        alasan: 'Kecepatan angin diprakirakan hingga $maxWindSpeed km/jam.',
        labelTag: 'Rutin',
      ),
    );
    highlights.add('angin hingga $maxWindSpeed km/jam');
  }

  final isStable = actions.isEmpty;
  if (isStable) {
    actions.add(
      const TindakanRekomendasi(
        judul: 'Lanjutkan Perawatan Rutin',
        deskripsi:
            'Cek EC dan pH larutan pada pagi hari serta bersihkan area tanam dari sisa daun.',
        alasan:
            'Kondisi cuaca relatif stabil tanpa peringatan suhu, hujan, atau angin ekstrem.',
        labelTag: 'Rutin',
      ),
    );
  }

  if (isStable) {
    return WeatherRuleEvaluation(
      summary:
          'Cuaca relatif stabil. Waktu yang baik untuk inspeksi dan perawatan rutin.',
      actions: List<TindakanRekomendasi>.unmodifiable(actions),
    );
  }

  final hasImportant = actions.any((action) => action.isPenting);
  return WeatherRuleEvaluation(
    summary:
        'Perhatikan ${_joinIndo(highlights)}. '
        '${hasImportant ? 'Utamakan tindakan berlabel Penting lebih dahulu.' : 'Lanjutkan perawatan rutin seperti biasa.'}',
    actions: List<TindakanRekomendasi>.unmodifiable(actions),
  );
}

String _joinIndo(List<String> items) {
  if (items.length == 1) return items.single;
  if (items.length == 2) return '${items.first} dan ${items.last}';
  return '${items.take(items.length - 1).join(', ')}, serta ${items.last}';
}
