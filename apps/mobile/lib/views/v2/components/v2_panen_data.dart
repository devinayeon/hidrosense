/// Data contoh untuk slice desain v2 “07 Panen”.
///
/// Semua angka diambil dari frame 7.1–7.23. Tanggal acuan sama dengan page
/// sebelumnya: 15 November 2026, sehingga estimasi “19 hari” dan “37 hari”
/// konsisten dengan HST di catatan alur.
library;

/// Tanggal acuan data contoh (frame 7.1).
final DateTime v2PanenHariIni = DateTime(2026, 11, 15);

/// Umur panen acuan: tanggal pindah + 45 hari.
const int v2PanenUmurHst = 45;

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

/// `6 Nov` — hari tanpa nol depan dan tanpa tahun (kicker kartu).
String labelTanggalPanen(DateTime tanggal) =>
    '${tanggal.day} ${_bulanSingkat[tanggal.month - 1]}';

/// `15 Nov 2026` — tanggal lengkap untuk isian form.
String labelTanggalPanenLengkap(DateTime tanggal) =>
    '${tanggal.day} ${_bulanSingkat[tanggal.month - 1]} ${tanggal.year}';

/// Angka berat tanpa desimal bila bulat (`252`, bukan `252.0`).
String labelBeratKg(double berat) {
  final bulat = berat == berat.roundToDouble();
  return bulat ? berat.toStringAsFixed(0) : berat.toStringAsFixed(1);
}

/// Saringan isi tab Panen (frame 7.1/7.6).
const List<String> labelChipPanen = <String>['Estimasi', 'Riwayat'];

/// Satu baris estimasi panen per meja (frame 7.1).
class V2PanenEstimasi {
  const V2PanenEstimasi({
    required this.meja,
    required this.varietas,
    required this.jumlahTanaman,
    required this.hariLagi,
    this.transferId,
  });

  final String meja;
  final String varietas;
  final int jumlahTanaman;

  /// 0 berarti panen hari ini (frame 7.1, Meja B1).
  final int hariLagi;

  /// Batch backend yang dipanen; null untuk data contoh galeri.
  final String? transferId;

  bool get siapPanen => hariLagi == 0;

  /// `Hari ini` atau `19 hari`.
  String get labelHari => siapPanen ? 'Hari ini' : '$hariLagi hari';

  /// `Romaine, 240`.
  String get labelTanaman => '$varietas, $jumlahTanaman';
}

/// Status kartu ringkasan panen (frame 7.14/7.16/7.17).
enum V2PanenStatus {
  /// Panen baru, belum ada penjualan (7.14).
  belumTerjual,

  /// Sebagian hasil sudah terjual (7.17).
  terjualSebagian,

  /// Menunggu sinkron (7.15/7.16).
  antrean,
}

/// Satu panen: berat, sisa, dan status penjualan.
class V2PanenItem {
  const V2PanenItem({
    required this.id,
    required this.tanggal,
    required this.meja,
    required this.varietas,
    required this.jumlahTanaman,
    required this.beratTotal,
    required this.beratReject,
    this.terjual = 0,
    this.antrean = false,
    this.keterangan,
    this.transferId,
  });

  final String id;
  final DateTime tanggal;
  final String meja;
  final String varietas;
  final int jumlahTanaman;
  final double beratTotal;
  final double beratReject;

  /// Berat yang sudah terjual; 0 berarti belum terjual.
  final double terjual;

  /// Panen belum tersimpan di server (frame 7.15/7.16).
  final bool antrean;

  final String? keterangan;

  /// Batch backend saat panen baru dicatat; null untuk riwayat/galeri.
  final String? transferId;

  /// Berat layak = berat total − reject (dihitung otomatis di 7.8).
  double get beratLayak => beratTotal - beratReject;

  /// Sisa yang belum terjual.
  double get sisa => beratLayak - terjual;

  V2PanenStatus get status {
    if (antrean) return V2PanenStatus.antrean;
    if (terjual <= 0) return V2PanenStatus.belumTerjual;
    return V2PanenStatus.terjualSebagian;
  }

  /// `Panen 6 Nov`.
  String get labelPanen => 'Panen ${labelTanggalPanen(tanggal)}';

  /// `252 kg`.
  String get labelBerat => '${labelBeratKg(beratLayak)} kg';

  /// `Meja A1. 250 tanaman. Reject 15 kg`
  String get labelMeta =>
      '$meja. $jumlahTanaman tanaman. '
      'Reject ${labelBeratKg(beratReject)} kg';

  /// Baris tambahan kartu ringkasan; beda untuk panen antrean (7.16).
  String get labelSisa {
    final terjualTeks = labelBeratKg(terjual);
    final sisaTeks = labelBeratKg(sisa);
    if (antrean) return 'Belum di server. Terjual $terjualTeks kg.';
    return 'Terjual $terjualTeks kg. Sisa $sisaTeks kg.';
  }

  V2PanenItem copyWith({
    double? beratTotal,
    double? beratReject,
    double? terjual,
    bool? antrean,
    String? keterangan,
  }) {
    return V2PanenItem(
      id: id,
      tanggal: tanggal,
      meja: meja,
      varietas: varietas,
      jumlahTanaman: jumlahTanaman,
      beratTotal: beratTotal ?? this.beratTotal,
      beratReject: beratReject ?? this.beratReject,
      terjual: terjual ?? this.terjual,
      antrean: antrean ?? this.antrean,
      keterangan: keterangan ?? this.keterangan,
      transferId: transferId,
    );
  }
}

/// Satu batang grafik riwayat: label tanggal dan berat layak.
class V2PanenGrafikBatang {
  V2PanenGrafikBatang({required this.label, required this.berat});

  final String label;
  final double berat;

  String get display => labelBeratKg(berat);
}

/// Estimasi panen siap panen lebih dulu, lalu yang paling dekat (frame 7.1).
final List<V2PanenEstimasi> designEstimasiPanen = <V2PanenEstimasi>[
  V2PanenEstimasi(
    meja: 'Meja B1',
    varietas: 'Romaine',
    jumlahTanaman: 240,
    hariLagi: 0,
  ),
  V2PanenEstimasi(
    meja: 'Meja A3',
    varietas: 'Butterhead',
    jumlahTanaman: 120,
    hariLagi: 19,
  ),
  V2PanenEstimasi(
    meja: 'Meja A2',
    varietas: 'Romaine',
    jumlahTanaman: 40,
    hariLagi: 37,
  ),
];

/// Panen 6 Nov 2026, Meja A1 (frame 7.6/7.17): 240 kg layak, terjual 90 kg.
final V2PanenItem designPanenTerjual = V2PanenItem(
  id: 'panen-6-nov',
  tanggal: DateTime(2026, 11, 6),
  meja: 'Meja A1',
  varietas: 'Romaine',
  jumlahTanaman: 250,
  beratTotal: 255,
  beratReject: 15,
  terjual: 90,
  keterangan: 'Panen pagi',
);

/// Panen 15 Nov 2026, Meja B1 (frame 7.14): 252 kg layak, belum terjual.
final V2PanenItem designPanenBaru = V2PanenItem(
  id: 'panen-15-nov',
  tanggal: DateTime(2026, 11, 15),
  meja: 'Meja B1',
  varietas: 'Romaine',
  jumlahTanaman: 240,
  beratTotal: 270,
  beratReject: 18,
  keterangan: 'Panen pagi',
);

/// Panen 15 Nov yang belum tersimpan di server (frame 7.15/7.16).
final V2PanenItem designPanenAntrean = V2PanenItem(
  id: 'panen-15-nov-antrean',
  tanggal: DateTime(2026, 11, 15),
  meja: 'Meja B1',
  varietas: 'Romaine',
  jumlahTanaman: 240,
  beratTotal: 270,
  beratReject: 18,
  antrean: true,
);

/// Isi chip Estimasi (frame 7.1/7.2).
/// Isi chip Riwayat pada frame 7.6: hanya panen 6 Nov.
final List<V2PanenItem> designPanenRiwayat = <V2PanenItem>[designPanenTerjual];

/// Isi chip Riwayat saat offline (frame 7.15): antrean di atas.
final List<V2PanenItem> designPanenRiwayatAntrean = <V2PanenItem>[
  designPanenAntrean,
  designPanenTerjual,
];

/// Grafik berat layak per panen (frame 7.6).
final List<V2PanenGrafikBatang> designGrafikPanen = <V2PanenGrafikBatang>[
  V2PanenGrafikBatang(label: '12 Okt', berat: 180),
  V2PanenGrafikBatang(label: '29 Okt', berat: 210),
  V2PanenGrafikBatang(label: '6 Nov', berat: 240),
];

/// Pilihan tanaman di sheet 7.9 (meja + varietas + jumlah).
final List<V2PanenEstimasi> designPilihanTanamanPanen = <V2PanenEstimasi>[
  V2PanenEstimasi(
    meja: 'Meja B1',
    varietas: 'Romaine',
    jumlahTanaman: 240,
    hariLagi: 0,
  ),
  V2PanenEstimasi(
    meja: 'Meja A3',
    varietas: 'Butterhead',
    jumlahTanaman: 120,
    hariLagi: 19,
  ),
  V2PanenEstimasi(
    meja: 'Meja A2',
    varietas: 'Romaine',
    jumlahTanaman: 40,
    hariLagi: 37,
  ),
];
