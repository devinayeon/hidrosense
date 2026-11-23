class TindakanRekomendasi {
  final String judul;
  final String deskripsi;
  final String alasan;
  final String labelTag; // Contoh: "Penting", "Rutin"
  final bool isPenting;

  /// Derajat kebenaran aturan fuzzy 0..1; null untuk tindakan rutin tanpa pemicu cuaca.
  final double? derajat;

  const TindakanRekomendasi({
    required this.judul,
    required this.deskripsi,
    required this.alasan,
    required this.labelTag,
    this.isPenting = false,
    this.derajat,
  });
}

class PrakiraanHarian {
  final String waktu; // Contoh: "Hari Ini • 25 Okt 2026"
  final String status; // Kondisi dominan, contoh: "Hujan Ringan"
  final int suhu; // Suhu maksimum harian, contoh: 29
  final String ringkasanSaran;
  final List<TindakanRekomendasi> rekomendasiList;

  const PrakiraanHarian({
    required this.waktu,
    required this.status,
    required this.suhu,
    required this.ringkasanSaran,
    required this.rekomendasiList,
  });
}

class WeatherData {
  final String lokasi;
  final String kota;
  final String sumber;
  final int suhu;
  final String statusSuhu;
  final int kelembapan;
  final String statusKelembapan;
  final String curahHujan;
  final String estimasiHujan;
  final int kecepatanAngin;
  final String arahAngin;
  final List<PrakiraanHarian> prakiraanHarian;
  final String lastUpdated;

  const WeatherData({
    required this.lokasi,
    required this.kota,
    required this.sumber,
    required this.suhu,
    required this.statusSuhu,
    required this.kelembapan,
    required this.statusKelembapan,
    required this.curahHujan,
    required this.estimasiHujan,
    required this.kecepatanAngin,
    required this.arahAngin,
    required this.prakiraanHarian,
    required this.lastUpdated,
  });
}
