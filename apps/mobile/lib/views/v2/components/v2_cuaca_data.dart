/// Data contoh untuk slice desain v2 “10 Cuaca BMKG”.
///
/// Semua angka diambil dari frame 10.1–10.11. Tanggal acuan tetap 15 November
/// 2026 supaya konsisten dengan page 05–09.
library;

/// Satu lokasi yang bisa dipilih di sheet 10.5.
class V2CuacaLokasi {
  const V2CuacaLokasi({required this.nama, required this.wilayah});

  final String nama;
  final String wilayah;

  /// `Sabrang, Ambulu, Jember`.
  String get label => '$nama, $wilayah';
}

/// Daftar lokasi cadangan saat data BMKG belum/tidak tersedia.
///
/// Lokasi mitra Hidro Selada ada di Desa Sabrang, Kecamatan Ambulu, Kabupaten
/// Jember (lihat `BmkgWeatherService`), jadi Ambulu diletakkan paling depan
/// sebagai pilihan awal. Sebelumnya daftar ini keliru menampilkan Malang/Batu/
/// Pasuruan (BUG-17): di lokasi mitra, kartu cuaca terlihat seperti salah desa.
const List<V2CuacaLokasi> designCuacaLokasi = <V2CuacaLokasi>[
  V2CuacaLokasi(nama: 'Sabrang', wilayah: 'Ambulu, Jember'),
  V2CuacaLokasi(nama: 'Ambulu', wilayah: 'Jember'),
  V2CuacaLokasi(nama: 'Jember', wilayah: 'Jawa Timur'),
];

/// Cuaca saat ini di kartu “Sekarang” (10.1, 10.5, 10.8).
class V2CuacaSekarang {
  const V2CuacaSekarang({
    required this.suhu,
    required this.kondisi,
    required this.catatan,
    required this.kelembapan,
    required this.angin,
    required this.hujan,
  });

  final String suhu;
  final String kondisi;
  final String catatan;
  final String kelembapan;
  final String angin;
  final String hujan;
}

const V2CuacaSekarang designCuacaSekarang = V2CuacaSekarang(
  suhu: '29°C',
  kondisi: 'Berawan',
  catatan: 'Hujan mulai 14.00',
  kelembapan: '78%',
  angin: '8 km/jam',
  hujan: '14.00 sampai 17.00',
);

/// Satu baris prakiraan (10.2, 10.9).
class V2CuacaHarian {
  const V2CuacaHarian({
    required this.hari,
    required this.kondisi,
    required this.suhu,
  });

  final String hari;
  final String kondisi;
  final String suhu;
}

const List<V2CuacaHarian> designCuacaPrakiraan = <V2CuacaHarian>[
  V2CuacaHarian(hari: 'Hari ini', kondisi: 'Hujan 14.00', suhu: '30°C'),
  V2CuacaHarian(hari: 'Senin 16 Nov', kondisi: 'Hujan ringan', suhu: '28°C'),
  V2CuacaHarian(hari: 'Selasa 17 Nov', kondisi: 'Berawan', suhu: '29°C'),
  V2CuacaHarian(hari: 'Rabu 18 Nov', kondisi: 'Cerah berawan', suhu: '31°C'),
];

/// Satu kartu saran perawatan (10.3).
class V2CuacaSaran {
  const V2CuacaSaran({
    required this.judul,
    required this.isi,
    required this.dasar,
  });

  final String judul;
  final String isi;
  final String dasar;
}

const List<V2CuacaSaran> designCuacaSaran = <V2CuacaSaran>[
  V2CuacaSaran(
    judul: 'Tunda penyemprotan',
    isi: 'Semprot besok pagi, bukan sore ini.',
    dasar: 'Dasar: hujan 14.00 sampai 17.00',
  ),
  V2CuacaSaran(
    judul: 'Periksa nutrisi setelah hujan',
    isi: 'Hujan bisa mengencerkan larutan nutrisi.',
    dasar: 'Dasar: hujan 14.00 sampai 17.00',
  ),
  V2CuacaSaran(
    judul: 'Tutup sisi persemaian',
    isi: 'Tutup sisi terbuka sebelum 14.00.',
    dasar: 'Dasar: angin 8 km/jam, hujan sore',
  ),
];

/// Baris kecil di bawah nama lokasi (10.1, 10.2, 10.3, 10.4, 10.11).
const String v2CuacaDiperbarui = 'Diperbarui 14.05. Sumber BMKG';

/// Baris kecil saat data berasal dari simpanan HP (10.8, 10.9, 10.10).
const String v2CuacaDataTerakhir = 'Data terakhir 14.05. Sumber BMKG';

/// Catatan abu di bawah kartu cuaca saat saran butuh internet (10.8).
const String v2CuacaSaranButuhInternet = 'Saran AI butuh internet.';
