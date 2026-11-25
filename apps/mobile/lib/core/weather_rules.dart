import 'formatting.dart';
import 'fuzzy_weather.dart';
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
  final hasRainText = descriptions.any(
    (description) => description.contains('hujan'),
  );
  final fuzzy = fuzzifyWeather(
    maxTemperature: maxTemperature,
    maxHumidity: maxHumidity,
    totalRainfallMm: totalRainfallMm,
    maxWindSpeed: maxWindSpeed,
    hasRainText: hasRainText,
  );

  final actions = <TindakanRekomendasi>[];
  final highlights = <String>[];

  /// Tindakan dengan derajat aturan fuzzy. Penting bila derajat ≥ 0,7, bila [canBeImportant].
  void add({
    required double degree,
    required String judul,
    required String deskripsi,
    required String alasan,
    required String highlight,
    bool canBeImportant = true,
  }) {
    final important = canBeImportant && degree >= kImportantDegree;
    actions.add(
      TindakanRekomendasi(
        judul: judul,
        deskripsi: deskripsi,
        alasan: '$alasan Derajat risiko ${(degree * 100).round()}%.',
        labelTag: important ? 'Penting' : 'Rutin',
        isPenting: important,
        derajat: degree,
      ),
    );
    highlights.add(highlight);
  }

  if (fuzzy.hot >= kImportantDegree) {
    add(
      degree: fuzzy.hot,
      judul: 'Atur Debit Nutrisi Meja NFT',
      deskripsi:
          'Tingkatkan sirkulasi dan debit aliran agar suhu larutan tetap stabil. Cek EC dan pH pada pagi atau sore hari.',
      alasan: 'Prakiraan suhu hingga $maxTemperature°C.',
      highlight: 'suhu panas hingga $maxTemperature°C',
    );
  } else if ((fuzzy.hot > fuzzy.warm ? fuzzy.hot : fuzzy.warm) >=
      kRelevantDegree) {
    add(
      degree: fuzzy.hot > fuzzy.warm ? fuzzy.hot : fuzzy.warm,
      judul: 'Pantau Suhu Larutan',
      deskripsi:
          'Catat suhu tandon dan pastikan pompa bekerja stabil saat suhu siang meningkat.',
      alasan: 'Suhu siang diprakirakan cukup hangat.',
      highlight: 'suhu siang hingga $maxTemperature°C',
      canBeImportant: false,
    );
  }

  if (fuzzy.rain >= kRelevantDegree) {
    final rainDescription = descriptions.firstWhere(
      (description) => description.contains('hujan'),
      orElse: () => 'hujan',
    );
    add(
      degree: fuzzy.rain,
      judul: 'Lindungi Instalasi & Sesuaikan Nutrisi',
      deskripsi:
          'Tutup tandon, pastikan drainase lancar, dan jaga EC larutan pada 1.2–1.4 mS/cm agar tidak terdilusi air hujan.',
      alasan:
          'BMKG memprakirakan $rainDescription dengan akumulasi ${formatAngka(totalRainfallMm)} mm.',
      highlight: 'peluang hujan ${formatAngka(totalRainfallMm)} mm',
    );
  }

  if (fuzzy.fungal >= kRelevantDegree) {
    add(
      degree: fuzzy.fungal,
      judul: 'Waspadai Jamur Daun',
      deskripsi:
          'Lakukan inspeksi daun dan atur ventilasi greenhouse. Semprot pencegahan hanya bila gejala jamur terlihat.',
      alasan: fuzzy.humid >= fuzzy.fungal
          ? 'Kelembapan udara mencapai $maxHumidity%.'
          : 'Udara lembap ($maxHumidity%) bersamaan dengan hujan.',
      highlight: 'kelembapan tinggi hingga $maxHumidity%',
    );
  }

  if (fuzzy.windy >= kRelevantDegree) {
    add(
      degree: fuzzy.windy,
      judul: 'Periksa Rangka & Naungan',
      deskripsi:
          'Pastikan rangka meja, naungan, dan penutup greenhouse terpasang kokoh.',
      alasan: 'Kecepatan angin diprakirakan hingga $maxWindSpeed km/jam.',
      highlight: 'angin hingga $maxWindSpeed km/jam',
      canBeImportant: false,
    );
  }

  if (fuzzy.pestPressure >= kRelevantDegree) {
    add(
      degree: fuzzy.pestPressure,
      judul: 'Tingkatkan Pemantauan Hama',
      deskripsi:
          'Periksa sisi bawah daun dan pucuk. Foto tanaman yang mencurigakan lewat menu Foto tanaman untuk saran rotasi obat.',
      alasan:
          'Cuaca hangat dan kering mendukung perkembangan thrips, kutu kebul, dan kutu daun.',
      highlight: 'cuaca hangat dan kering yang disukai hama',
      canBeImportant: false,
    );
  }

  if (actions.isEmpty) {
    return WeatherRuleEvaluation(
      summary:
          'Cuaca relatif stabil. Waktu yang baik untuk inspeksi dan perawatan rutin.',
      actions: List<TindakanRekomendasi>.unmodifiable(const [
        TindakanRekomendasi(
          judul: 'Lanjutkan Perawatan Rutin',
          deskripsi:
              'Cek EC dan pH larutan pada pagi hari serta bersihkan area tanam dari sisa daun.',
          alasan:
              'Kondisi cuaca relatif stabil tanpa peringatan suhu, hujan, atau angin ekstrem.',
          labelTag: 'Rutin',
        ),
      ]),
    );
  }

  // Urut menurut derajat: yang paling yakin dan paling mendesak di atas.
  final ordered = [...actions]
    ..sort((a, b) => (b.derajat ?? 0).compareTo(a.derajat ?? 0));
  final hasImportant = ordered.any((action) => action.isPenting);
  return WeatherRuleEvaluation(
    summary:
        'Perhatikan ${_joinIndo(highlights)}. '
        '${hasImportant ? 'Utamakan tindakan berlabel Penting lebih dahulu.' : 'Lanjutkan perawatan rutin seperti biasa.'}',
    actions: List<TindakanRekomendasi>.unmodifiable(ordered),
  );
}

String _joinIndo(List<String> items) {
  if (items.length == 1) return items.single;
  if (items.length == 2) return '${items.first} dan ${items.last}';
  return '${items.take(items.length - 1).join(', ')}, serta ${items.last}';
}
