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
    this.panenId,
    this.tanggalPanen,
    this.version,
    this.sync = V2PenjualanSync.terkirim,
  });

  final String id;
  final String pembeli;
  final DateTime tanggal;
  final double jumlahKg;
  final double hargaPerKg;
  final V2PenjualanBayar pembayaran;

  /// Label panen di kolom form dan sheet pemilih, mis. "Panen 6 Nov, sisa
  /// 150 kg".
  final String panen;

  /// Baris asal panen di kartu detail, mis. "Dari panen 6 Nov, Meja A1".
  final String panenAsal;

  /// Id batch panen di server; null bila penjualan memuat beberapa panen.
  final String? panenId;

  /// Tanggal panen asal; dipakai label pilihan panen saat mengubah.
  final DateTime? tanggalPanen;

  /// Versi baris di server (dipakai pengiriman ulang dan konflik).
  final String? version;

  final V2PenjualanSync sync;

  bool get lunas => pembayaran == V2PenjualanBayar.lunas;
  bool get antrean => sync == V2PenjualanSync.antrean;

  /// Baris multi-panen: jumlah dan harga per baris tidak bisa diubah dari
  /// aplikasi, hanya pembeli/tanggal/status (sama seperti v1).
  bool get multiBatch => panenId == null;

  double get total => jumlahKg * hargaPerKg;

  V2Penjualan copyWith({
    String? pembeli,
    DateTime? tanggal,
    double? jumlahKg,
    double? hargaPerKg,
    V2PenjualanBayar? pembayaran,
    String? panen,
    String? panenAsal,
    String? panenId,
    DateTime? tanggalPanen,
    String? version,
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
      panenId: panenId ?? this.panenId,
      tanggalPanen: tanggalPanen ?? this.tanggalPanen,
      version: version ?? this.version,
      sync: sync ?? this.sync,
    );
  }
}

/// Satu pilihan panen di sheet "Pilih panen" (frame 8.9).
class V2PenjualanPanen {
  const V2PenjualanPanen({
    this.id,
    required this.tanggalPanen,
    required this.sisaKg,
  });

  /// Id batch di server; null untuk data contoh galeri.
  final String? id;

  final DateTime tanggalPanen;
  final double sisaKg;

  bool get tersedia => sisaKg > 0;

  /// Label baris pilihan, mis. "Panen 6 Nov, sisa 150 kg".
  String get label =>
      'Panen ${formatTanggalPendek(tanggalPanen)}, sisa ${formatKg(sisaKg)}';
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
  var total = 0.0;
  var kg = 0.0;
  var belumLunas = 0.0;
  for (final item in items) {
    total += item.total;
    kg += item.jumlahKg;
    if (!item.lunas) belumLunas += item.total;
  }
  return V2PenjualanRingkasan(
    kicker: kicker,
    total: formatRupiahPenuh(total),
    kgTerjual: '${formatKg(kg)} terjual',
    belumLunas: 'Belum lunas ${formatRupiahPenuh(belumLunas)}',
    adaBelumLunas: belumLunas > 0,
  );
}

/// Satu bulan pada grafik ringkasan penjualan (frame 8.5).
class V2PenjualanBulan {
  const V2PenjualanBulan({
    required this.label,
    required this.totalRupiah,
    required this.kg,
  });

  /// Nama bulan singkat, mis. `Nov`.
  final String label;
  final double totalRupiah;
  final double kg;

  /// Tinggi batang dipakai kartu grafik; nilainya dalam juta rupiah.
  double get juta => totalRupiah / 1000000;

  /// Angka di atas batang, mis. `7,5`.
  String get display => formatJutaAkurat(totalRupiah);
}

/// Isi halaman ringkasan 8.5 yang dihitung dari data nyata.
class V2PenjualanRingkasanBulanan {
  const V2PenjualanRingkasanBulanan({
    required this.bulan,
    required this.totalTigaBulan,
    required this.rataRataPerKg,
    required this.belumLunas,
  });

  /// Tiga bulan berurutan, paling lama di depan (Sep, Okt, Nov).
  final List<V2PenjualanBulan> bulan;
  final double totalTigaBulan;

  /// Rata-rata rupiah per kg seluruh tiga bulan; 0 bila belum ada berat.
  final double rataRataPerKg;

  /// Sisa penjualan yang belum lunas pada tiga bulan itu.
  final double belumLunas;

  /// `Sep 5,2 juta, Okt 6,4 juta, Nov 7,5 juta.`
  String get caption =>
      '${bulan.map((item) => '${item.label} ${item.display} juta').join(', ')}.';
}

/// Menghitung ringkasan 8.5 dari [items]: bulan [sekarang] dan dua sebelumnya.
V2PenjualanRingkasanBulanan ringkasanBulananPenjualan(
  List<V2Penjualan> items, {
  required DateTime sekarang,
}) {
  final bulan = <V2PenjualanBulan>[];
  var totalTigaBulan = 0.0;
  var kgTigaBulan = 0.0;
  var belumLunas = 0.0;
  for (var mundur = 2; mundur >= 0; mundur--) {
    final acuan = DateTime(sekarang.year, sekarang.month - mundur);
    var total = 0.0;
    var kg = 0.0;
    for (final item in items) {
      if (item.tanggal.year != acuan.year ||
          item.tanggal.month != acuan.month) {
        continue;
      }
      total += item.total;
      kg += item.jumlahKg;
      if (!item.lunas) belumLunas += item.total;
    }
    totalTigaBulan += total;
    kgTigaBulan += kg;
    bulan.add(
      V2PenjualanBulan(
        label: _bulanSingkat[acuan.month - 1],
        totalRupiah: total,
        kg: kg,
      ),
    );
  }
  return V2PenjualanRingkasanBulanan(
    bulan: List.unmodifiable(bulan),
    totalTigaBulan: totalTigaBulan,
    rataRataPerKg: kgTigaBulan == 0 ? 0 : totalTigaBulan / kgTigaBulan,
    belumLunas: belumLunas,
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

const List<String> _bulanPanjang = <String>[
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

/// `2400000` menjadi `Rp 2.400.000` (kartu detail dan ringkasan).
String formatRupiahPenuh(num value) =>
    'Rp ${formatAngkaRibu(value.round())}';

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

/// `60` menjadi `60 kg`, `60.5` menjadi `60,5 kg` (baris daftar/label panen).
String formatKg(double value) => '${formatAngkaKg(value)} kg';

/// Angka desimal gaya lokal tanpa satuan: `5.2` -> `5,2`, `5.0` -> `5`.
String formatAngkaDesimal(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value
          .toStringAsFixed(2)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceAll('.', ',');

/// Angka kg tanpa satuan; koma dipakai sebagai desimal seperti kebiasaan lokal.
String formatAngkaKg(double value) => formatAngkaDesimal(value);

/// Angka juta tanpa satuan untuk label batang: `7500000` -> `7,5` (frame 8.5).
String formatJutaAkurat(num rupiah) =>
    formatAngkaDesimal(rupiah / 1000000);

/// Membaca isian kg; `60,5` dan `60.5` sama-sama dibaca `60.5`.
double parseKg(String text) {
  var value = text.trim();
  if (value.contains(',')) {
    value = value.replaceAll('.', '').replaceAll(',', '.');
  }
  return double.tryParse(value) ?? 0;
}

/// `2400000` menjadi `Rp 2,4 jt` dan `1260000` menjadi `Rp 1,26 jt` —
/// kolom nilai di baris daftar (frame 8.1/8.6/8.16).
String formatRupiahJuta(num value) {
  var text = (value / 1000000).toStringAsFixed(2);
  if (text.endsWith('00')) {
    text = text.substring(0, text.length - 3);
  } else if (text.endsWith('0')) {
    text = text.substring(0, text.length - 1);
  }
  return 'Rp ${text.replaceAll('.', ',')} jt';
}

/// `6 Nov 2026` -> `6 Nov` untuk label panen.
String formatTanggalPendek(DateTime tanggal) =>
    '${tanggal.day} ${_bulanSingkat[tanggal.month - 1]}';

/// `18 Nov 2026` -> `November 2026` untuk judul kartu ringkasan.
String formatBulanTahun(DateTime tanggal) =>
    '${_bulanPanjang[tanggal.month - 1]} ${tanggal.year}';

/// `15 Nov 2026` — kolom tanggal di form.
String formatTanggalPenjualan(DateTime tanggal) =>
    '${tanggal.day} ${_bulanSingkat[tanggal.month - 1]} ${tanggal.year}';

/// `12 Nov. 60 kg` — baris kedua tiap baris daftar.
String formatSubJudulPenjualan(V2Penjualan penjualan) =>
    '${penjualan.tanggal.day} ${_bulanSingkat[penjualan.tanggal.month - 1]}. '
    '${formatKg(penjualan.jumlahKg)}';

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
  panenId: 'panen-6-nov',
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
  panenId: 'panen-6-nov',
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
  panenId: 'panen-6-nov',
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
  panenId: 'panen-6-nov',
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
final List<V2PenjualanPanen> designPanen = <V2PenjualanPanen>[
  V2PenjualanPanen(tanggalPanen: DateTime(2026, 11, 6), sisaKg: 150),
  V2PenjualanPanen(tanggalPanen: DateTime(2026, 10, 29), sisaKg: 0),
  V2PenjualanPanen(tanggalPanen: DateTime(2026, 10, 12), sisaKg: 0),
];
