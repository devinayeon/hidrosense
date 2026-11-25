/// Data contoh untuk slice desain v2 “09 Perawatan & Hama”.
///
/// Semua angka diambil dari frame 9.1–9.28. Tanggal acuan tetap 15 November
/// 2026 supaya konsisten dengan page 05–07.
library;

/// Tanggal acuan data contoh (frame 9.14, 9.24).
final DateTime v2RawatHariIni = DateTime(2026, 11, 15);

const List<String> _bulanSingkat = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

/// `12 Nov` — tanggal tanpa tahun untuk baris riwayat.
String labelTanggalRawat(DateTime tanggal) =>
    '${tanggal.day} ${_bulanSingkat[tanggal.month - 1]}';

/// `15 Nov 2026` — tanggal lengkap untuk isian form.
String labelTanggalRawatLengkap(DateTime tanggal) =>
    '${tanggal.day} ${_bulanSingkat[tanggal.month - 1]} ${tanggal.year}';

/// Status rekomendasi untuk satu pindaian di tab Rawat.
enum V2PindaiStatus {
  menunggu('Menunggu'),
  diterima('Diterima'),
  ditolak('Ditolak');

  const V2PindaiStatus(this.label);

  final String label;
}

/// Satu baris “Pindaian terbaru” di tab Rawat: foto yang sudah dianalisis model.
///
/// Data ini berasal dari `GET /pindaian`, bukan contoh desain, jadi [hama] dan
/// [keyakinan] apa adanya dari server.
class V2PindaiItem {
  const V2PindaiItem({
    required this.id,
    required this.hama,
    required this.meja,
    required this.tanggal,
    this.keyakinan,
    this.status,
    this.rincian = const <String>[],
  });

  final String id;

  /// Nama hama yang terdeteksi, mis. `Thrips, Kutu kebul`; `Tidak ada hama` bila bersih.
  final String hama;
  final String meja;
  final DateTime tanggal;

  /// Keyakinan tertinggi dalam persen; null bila server tidak menyimpannya.
  final int? keyakinan;

  /// Status rekomendasi obat untuk foto ini; null bila belum ada rekomendasi.
  final V2PindaiStatus? status;

  /// Rincian per hama untuk halaman detail, mis. `Thrips · 3 ekor · 87%`.
  final List<String> rincian;

  String get labelTanggal => labelTanggalRawat(tanggal);

  /// `Meja A2, 24 Nov`.
  String get labelKicker => '$meja, $labelTanggal';

  /// `87%` atau `Tanpa keyakinan`.
  String get labelKeyakinan =>
      keyakinan == null ? 'Tanpa keyakinan' : '$keyakinan%';
}

/// Status satu catatan perawatan.
enum V2RawatStatus {
  /// Sudah tersimpan di server (9.1, 9.24, 9.27).
  selesai,

  /// Menunggu sinkron di HP (9.11, 9.25, 9.26).
  antrean,
}

/// Satu catatan riwayat perawatan (baris `StockItem` 9.1/9.11/9.25).
class V2RawatItem {
  const V2RawatItem({
    required this.id,
    required this.hama,
    required this.meja,
    required this.tanggal,
    this.obat = 'Obat Nabati',
    this.jumlahObat = 1,
    this.keyakinan = 87,
    this.status = V2RawatStatus.selesai,
    this.foto = false,
    this.meta,
    this.extra,
  });

  final String id;

  /// Nama hama; diabaikan saat [foto] menyala.
  final String hama;
  final String meja;
  final DateTime tanggal;
  final String obat;
  final int jumlahObat;
  final int keyakinan;
  final V2RawatStatus status;

  /// Baris “Foto daun” yang masih menunggu analisis (frame 9.11).
  final bool foto;

  /// Subjudul kartu detail; null berarti `obat, jumlah botol` dari desain.
  final String? meta;

  /// Baris tambahan kartu detail; null berarti `Keyakinan 87%. Saran AI.`.
  final String? extra;

  bool get antrean => status == V2RawatStatus.antrean;

  /// `Thrips` atau `Foto daun`.
  String get judul => foto ? 'Foto daun' : hama;

  String get labelTanggal => labelTanggalRawat(tanggal);

  /// `Meja A2, 15 Nov`.
  String get labelKicker => '$meja, $labelTanggal';

  /// `Obat Nabati, 1 botol`.
  String get labelObat => meta ?? '$obat, $jumlahObat botol';

  /// `Keyakinan 87%. Saran AI.` atau catatan antrean (frame 9.26).
  String get labelExtra =>
      extra ??
      (antrean
          ? 'Belum di server. Saran AI.'
          : 'Keyakinan $keyakinan%. Saran AI.');

  V2RawatItem copyWith({String? obat, int? jumlahObat, V2RawatStatus? status}) {
    return V2RawatItem(
      id: id,
      hama: hama,
      meja: meja,
      tanggal: tanggal,
      obat: obat ?? this.obat,
      jumlahObat: jumlahObat ?? this.jumlahObat,
      keyakinan: keyakinan,
      status: status ?? this.status,
      foto: foto,
      meta: meta,
      extra: extra,
    );
  }
}

/// Satu hama pada hasil analisis (frame 9.14/9.15).
class V2Hama {
  const V2Hama({required this.nama, required this.keyakinan});

  final String nama;

  /// Persentase keyakinan AI, mis. 87.
  final int keyakinan;

  /// `Keyakinan tinggi` ≥ 80, `sedang` ≥ 50, selebihnya `rendah`.
  String get labelKeyakinan {
    if (keyakinan >= 80) return 'Keyakinan tinggi';
    if (keyakinan >= 50) return 'Keyakinan sedang';
    return 'Keyakinan rendah';
  }

  /// `87%`.
  String get labelPersen => '$keyakinan%';
}

/// Satu pilihan obat di halaman rekomendasi (frame 9.19/9.20).
class V2Obat {
  const V2Obat({required this.nama, required this.stok});

  final String nama;

  /// Sisa botol di stok; 0 berarti habis.
  final int stok;

  bool get habis => stok <= 0;

  /// `Obat Nabati, stok 1 botol` atau `Minyak neem, habis`.
  String get label => habis ? '$nama, habis' : '$nama, stok $stok botol';

  /// Pesan kartu “Stok berkurang” (frame 9.21).
  String labelSisa(int jumlah) {
    final sisa = stok - jumlah;
    return '$nama: $stok botol jadi ${sisa < 0 ? 0 : sisa} botol';
  }
}

const V2Hama designHamaThrips = V2Hama(nama: 'Thrips', keyakinan: 87);
const V2Hama designHamaKutuDaun = V2Hama(nama: 'Kutu daun', keyakinan: 64);
const V2Hama designHamaRendah = V2Hama(nama: 'Thrips', keyakinan: 42);

const V2Obat designObatNabati = V2Obat(nama: 'Obat Nabati', stok: 1);
const V2Obat designObatSabun = V2Obat(nama: 'Sabun insektisida', stok: 3);

const List<V2Obat> designObatThrips = <V2Obat>[
  designObatNabati,
  designObatSabun,
  V2Obat(nama: 'Minyak neem', stok: 0),
];

const List<V2Obat> designObatKutuDaun = <V2Obat>[
  designObatSabun,
  designObatNabati,
  V2Obat(nama: 'Minyak neem', stok: 0),
];

/// Perawatan Thrips 12 Nov (frame 9.1/9.27).
final V2RawatItem designRawatSelesai12 = V2RawatItem(
  id: 'rawat-12-nov',
  hama: 'Thrips',
  meja: 'Meja A2',
  tanggal: DateTime(2026, 11, 12),
  obat: 'Sabun insektisida',
  keyakinan: 87,
);

/// Perawatan Kutu daun 5 Nov (baris kedua 9.1).
final V2RawatItem designRawatSelesai5 = V2RawatItem(
  id: 'rawat-5-nov',
  hama: 'Kutu daun',
  meja: 'Meja A3',
  tanggal: DateTime(2026, 11, 5),
  obat: 'Obat Nabati',
  keyakinan: 64,
);

/// Perawatan baru 15 Nov yang belum sinkron (frame 9.25/9.26).
final V2RawatItem designRawatAntrean = V2RawatItem(
  id: 'rawat-15-nov-antrean',
  hama: 'Thrips',
  meja: 'Meja A2',
  tanggal: DateTime(2026, 11, 15),
  obat: 'Obat Nabati',
  keyakinan: 87,
  status: V2RawatStatus.antrean,
);

/// Perawatan baru 15 Nov setelah konfirmasi (frame 9.24).
final V2RawatItem designRawatBaru = V2RawatItem(
  id: 'rawat-15-nov',
  hama: 'Thrips',
  meja: 'Meja A2',
  tanggal: DateTime(2026, 11, 15),
  obat: 'Obat Nabati',
  keyakinan: 87,
);

/// Baris “Foto daun” yang menunggu analisis (frame 9.11).
final V2RawatItem designRawatFotoAntrean = V2RawatItem(
  id: 'foto-15-nov-antrean',
  hama: 'Foto daun',
  meja: 'Meja A2',
  tanggal: DateTime(2026, 11, 15),
  foto: true,
  status: V2RawatStatus.antrean,
);

/// Riwayat tab Rawat (frame 9.1): 12 Nov lalu 5 Nov.
final List<V2RawatItem> designRawatRiwayat = <V2RawatItem>[
  designRawatSelesai12,
  designRawatSelesai5,
];

/// Riwayat setelah foto disimpan di HP (frame 9.11).
final List<V2RawatItem> designRawatRiwayatFoto = <V2RawatItem>[
  designRawatFotoAntrean,
  designRawatSelesai12,
];

/// Riwayat setelah perawatan disimpan di HP (frame 9.25).
final List<V2RawatItem> designRawatRiwayatAntrean = <V2RawatItem>[
  designRawatAntrean,
  designRawatSelesai12,
];
