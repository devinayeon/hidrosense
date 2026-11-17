/// Model dan data contoh alur "08 Penjualan".
///
/// Satu penjualan punya dua hal yang berbeda dan sering tertukar di desain:
/// status pembayaran ([V2PenjualanBayar], sejalan dengan `status_pembayaran`
/// backend) dan keadaan sinkron ([V2PenjualanSync]). Badge "Antrean" di frame
/// 8.16/8.17 berasal dari [V2PenjualanSync], bukan dari pembayaran.
library;

/// Status pembayaran penjualan.
enum V2PenjualanBayar {
  /// Wire: `lunas`.
  lunas,

  /// Wire: `belum_lunas`.
  belumLunas,
}

/// Apakah penjualan sudah terkirim ke server.
enum V2PenjualanSync { terkirim, antrean }

/// Satu catatan penjualan.
class V2Penjualan {
  const V2Penjualan({
    required this.id,
    required this.pembeli,
    required this.tanggal,
    required this.jumlahKg,
    required this.hargaPerKg,
    required this.pembayaran,
    required this.panen,
    required this.panenAsal,
    this.sync = V2PenjualanSync.terkirim,
  });

  final String id;
  final String pembeli;
  final DateTime tanggal;
  final int jumlahKg;
  final int hargaPerKg;
  final V2PenjualanBayar pembayaran;

  /// Label panen di kolom form dan sheet pemilih, mis. "Panen 6 Nov, sisa
  /// 150 kg".
  final String panen;

  /// Baris asal panen di kartu detail, mis. "Dari panen 6 Nov, Meja A1".
  final String panenAsal;

  final V2PenjualanSync sync;

  bool get lunas => pembayaran == V2PenjualanBayar.lunas;
  bool get antrean => sync == V2PenjualanSync.antrean;

  int get total => jumlahKg * hargaPerKg;

  V2Penjualan copyWith({
    String? pembeli,
    DateTime? tanggal,
    int? jumlahKg,
    int? hargaPerKg,
    V2PenjualanBayar? pembayaran,
    String? panen,
    String? panenAsal,
    V2PenjualanSync? sync,
  }) {
    return V2Penjualan(
      id: id,
      pembeli: pembeli ?? this.pembeli,
      tanggal: tanggal ?? this.tanggal,
      jumlahKg: jumlahKg ?? this.jumlahKg,
      hargaPerKg: hargaPerKg ?? this.hargaPerKg,
      pembayaran: pembayaran ?? this.pembayaran,
      panen: panen ?? this.panen,
      panenAsal: panenAsal ?? this.panenAsal,
      sync: sync ?? this.sync,
    );
  }
}

/// Satu pilihan panen di sheet "Pilih panen" (frame 8.9).
class V2PenjualanPanen {
  const V2PenjualanPanen({required this.label, required this.sisaKg});

  final String label;
  final int sisaKg;

  bool get tersedia => sisaKg > 0;
}

/// Isi `SummaryCard` di puncak halaman penjualan.
class V2PenjualanRingkasan {
  const V2PenjualanRingkasan({
    required this.kicker,
    required this.total,
    required this.kgTerjual,
    required this.belumLunas,
    this.adaBelumLunas = true,
  });

  /// Judul kecil di kiri, mis. "November 2026".
  final String kicker;
  final String total;
  final String kgTerjual;

  /// Baris kecil terbawah, mis. "Belum lunas Rp 2.400.000".
  final String belumLunas;

  /// Menyalakan badge kuning "Belum lunas" di kanan judul.
  final bool adaBelumLunas;
}

/// Ringkasan yang dihitung dari [items]; dipakai saat data sudah nyata.
V2PenjualanRingkasan ringkasanPenjualan(
  List<V2Penjualan> items, {
  required String kicker,
}) {
  var total = 0;
  var kg = 0;
  var belumLunas = 0;
  for (final item in items) {
    total += item.total;
    kg += item.jumlahKg;
    if (!item.lunas) belumLunas += item.total;
  }
  return V2PenjualanRingkasan(
    kicker: kicker,
    total: formatRupiahPenuh(total),
    kgTerjual: '$kg kg terjual',
    belumLunas: 'Belum lunas ${formatRupiahPenuh(belumLunas)}',
    adaBelumLunas: belumLunas > 0,
  );
}

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

/// `2400000` menjadi `Rp 2.400.000` (kartu detail dan ringkasan).
String formatRupiahPenuh(int value) => 'Rp ${formatAngkaRibu(value)}';

/// `40000` menjadi `40.000` — nilai yang dirapikan di kolom angka form.
String formatAngkaRibu(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write('.');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}

/// Isi kolom angka kembali menjadi bilangan; `40.000` dan `40000` sama-sama
/// dibaca `40000` supaya titik ribuan boleh diketik pemakai.
int parseAngkaRibu(String text) =>
    int.tryParse(text.replaceAll(RegExp('[^0-9]'), '')) ?? 0;

/// `2400000` menjadi `Rp 2,4 jt` dan `1260000` menjadi `Rp 1,26 jt` —
/// kolom nilai di baris daftar (frame 8.1/8.6/8.16).
String formatRupiahJuta(int value) {
  var text = (value / 1000000).toStringAsFixed(2);
  if (text.endsWith('00')) {
    text = text.substring(0, text.length - 3);
  } else if (text.endsWith('0')) {
    text = text.substring(0, text.length - 1);
  }
  return 'Rp ${text.replaceAll('.', ',')} jt';
}

/// `15 Nov 2026` — kolom tanggal di form.
String formatTanggalPenjualan(DateTime tanggal) =>
    '${tanggal.day} ${_bulanSingkat[tanggal.month - 1]} ${tanggal.year}';

/// `12 Nov. 60 kg` — baris kedua tiap baris daftar.
String formatSubJudulPenjualan(V2Penjualan penjualan) =>
    '${penjualan.tanggal.day} ${_bulanSingkat[penjualan.tanggal.month - 1]}. '
    '${penjualan.jumlahKg} kg';

/// `12 Nov. 60 kg x Rp 40.000` — baris Meta kartu detail.
String formatMetaPenjualan(V2Penjualan penjualan) =>
    '${formatSubJudulPenjualan(penjualan)} x '
    '${formatRupiahPenuh(penjualan.hargaPerKg)}';

// --- Data contoh (frame 8.1–8.24) -----------------------------------------

/// Toko Segar, 12 Nov, 60 kg, belum lunas (frame 8.1, 8.14, 8.16, 8.18).
final V2Penjualan penjualanTokoSegar = V2Penjualan(
  id: 'sale-toko-segar',
  pembeli: 'Toko Segar',
  tanggal: DateTime(2026, 11, 12),
  jumlahKg: 60,
  hargaPerKg: 40000,
  pembayaran: V2PenjualanBayar.belumLunas,
  panen: 'Panen 6 Nov, sisa 150 kg',
  panenAsal: 'Dari panen 6 Nov, Meja A1',
);

/// Versi Toko Segar setelah diubah (frame 8.22, harga naik jadi 41.000).
final V2Penjualan penjualanTokoSegarDiubah = penjualanTokoSegar.copyWith(
  hargaPerKg: 41000,
);

/// Pasar Induk, 8 Nov, 30 kg, lunas (frame 8.1, 8.14, 8.19).
final V2Penjualan penjualanPasarInduk = V2Penjualan(
  id: 'sale-pasar-induk',
  pembeli: 'Pasar Induk',
  tanggal: DateTime(2026, 11, 8),
  jumlahKg: 30,
  hargaPerKg: 42000,
  pembayaran: V2PenjualanBayar.lunas,
  panen: 'Panen 6 Nov, sisa 150 kg',
  panenAsal: 'Dari panen 6 Nov, Meja A1',
);

/// Resto Hijau, 2 Nov, 100 kg, lunas (frame 8.1).
final V2Penjualan penjualanRestoHijau = V2Penjualan(
  id: 'sale-resto-hijau',
  pembeli: 'Resto Hijau',
  tanggal: DateTime(2026, 11, 2),
  jumlahKg: 100,
  hargaPerKg: 38000,
  pembayaran: V2PenjualanBayar.lunas,
  panen: 'Panen 6 Nov, sisa 150 kg',
  panenAsal: 'Dari panen 6 Nov, Meja A1',
);

/// Warung Sari, 15 Nov, 60 kg, belum lunas (frame 8.14, 8.15, 8.16, 8.17).
final V2Penjualan penjualanWarungSari = V2Penjualan(
  id: 'sale-warung-sari',
  pembeli: 'Warung Sari',
  tanggal: DateTime(2026, 11, 15),
  jumlahKg: 60,
  hargaPerKg: 40000,
  pembayaran: V2PenjualanBayar.belumLunas,
  panen: 'Panen 6 Nov, sisa 150 kg',
  panenAsal: 'Dari panen 6 Nov, Meja A1',
);

/// Tiga baris frame 8.1.
final List<V2Penjualan> designPenjualan = <V2Penjualan>[
  penjualanTokoSegar,
  penjualanPasarInduk,
  penjualanRestoHijau,
];

/// Tiga baris frame 8.14 (satu penjualan baru masuk paling atas).
final List<V2Penjualan> designPenjualanBaru = <V2Penjualan>[
  penjualanWarungSari,
  penjualanTokoSegar,
  penjualanPasarInduk,
];

/// Versi antrean Warung Sari (frame 8.16/8.17): belum terkirim ke server.
final V2Penjualan penjualanWarungSariAntrean = penjualanWarungSari.copyWith(
  sync: V2PenjualanSync.antrean,
);

/// Dua baris frame 8.16: satu penjualan masih di antrean, satu belum lunas.
final List<V2Penjualan> designPenjualanOffline = <V2Penjualan>[
  penjualanWarungSariAntrean,
  penjualanTokoSegar,
];

/// Isi kartu ringkasan frame 8.1/8.6/8.16.
const V2PenjualanRingkasan designRingkasanPenjualan = V2PenjualanRingkasan(
  kicker: 'November 2026',
  total: 'Rp 7.460.000',
  kgTerjual: '190 kg terjual',
  belumLunas: 'Belum lunas Rp 2.400.000',
);

/// Isi kartu ringkasan frame 8.14.
const V2PenjualanRingkasan designRingkasanPenjualanBaru = V2PenjualanRingkasan(
  kicker: 'November 2026',
  total: 'Rp 9.860.000',
  kgTerjual: '250 kg terjual',
  belumLunas: 'Belum lunas Rp 4.800.000',
);

/// Pilihan panen di sheet 8.9; yang sisa 0 kg tidak bisa dipilih.
const List<V2PenjualanPanen> designPanen = <V2PenjualanPanen>[
  V2PenjualanPanen(label: 'Panen 6 Nov, sisa 150 kg', sisaKg: 150),
  V2PenjualanPanen(label: 'Panen 29 Okt, sisa 0 kg', sisaKg: 0),
  V2PenjualanPanen(label: 'Panen 12 Okt, sisa 0 kg', sisaKg: 0),
];
