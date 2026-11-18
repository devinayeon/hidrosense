/// Model dan data contoh alur "05 Semaian".
///
/// Umur semaian dihitung dari tanggal semai dan disebut HSS (hari setelah
/// semai). Semua angka di frame (17, 10, 3, 23) diukur dari satu tanggal acuan
/// [v2SemaianHariIni] supaya data contoh tidak ikut bergeser saat aplikasi
/// dibuka di hari lain.
library;

/// Tanggal acuan data contoh page 05, 15 Nov 2026.
///
/// 29 Okt + 17, 5 Nov + 10, 12 Nov + 3, dan 23 Okt + 23 semuanya jatuh di
/// tanggal ini; itulah HSS pada frame 5.1–5.6, 5.15, dan 5.16.
final DateTime v2SemaianHariIni = DateTime(2026, 11, 15);

/// Semaian siap pindah ke meja saat umurnya mencapai HSS ini (frame 5.15/5.16).
const int v2SemaianHssSiapPindah = 15;

/// Umur semaian dalam hari sejak [tanggalSemai] (HSS).
///
/// Dihitung dari tanggal saja, dalam UTC, supaya jam dan pergantian waktu
/// musim panas tidak membuat satu hari hilang.
int hssSemaian(DateTime tanggalSemai, {DateTime? hariIni}) {
  final acuan = hariIni ?? v2SemaianHariIni;
  final awal = DateTime.utc(
    tanggalSemai.year,
    tanggalSemai.month,
    tanggalSemai.day,
  );
  final akhir = DateTime.utc(acuan.year, acuan.month, acuan.day);
  return akhir.difference(awal).inDays;
}

/// Keadaan satu semaian; menentukan lencana di baris dan kartu detail.
enum V2SemaianStatus {
  /// Belum genap 15 hari; lencana "Berjalan" (frame 5.15).
  berjalan,

  /// Umur sudah 15 hari atau lebih; lencana "Siap pindah" (frame 5.16).
  siapPindah,

  /// Sudah ditandai selesai; baris memudar, tanpa lencana (frame 5.6).
  selesai,
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

/// `29 Okt` — hari tanpa angka nol di depan dan tanpa tahun, seperti subjudul
/// "Semai 29 Okt" di frame 5.1.
String labelTanggalSemai(DateTime tanggal) =>
    '${tanggal.day} ${_bulanSingkat[tanggal.month - 1]}';

/// Saringan keadaan semaian (frame 5.1/5.6).
const List<String> labelChipSemaian = <String>['Semua', 'Siap pindah', 'Selesai'];

/// Satu baris semaian.
class V2SemaianItem {
  const V2SemaianItem({
    required this.id,
    required this.nama,
    required this.tanggalSemai,
    required this.jumlahBenih,
    this.selesai = false,
    this.antrean = false,
    this.jumlahBahan = 2,
    this.sisaBenih,
    this.jumlahPindah,
    this.pindahKe,
    this.tidakDipindah,
  });

  final String id;

  /// Nama benih yang disemai, mis. `Romaine`.
  final String nama;

  /// Tanggal benih disemai; umur dihitung dari sini.
  final DateTime tanggalSemai;

  /// Banyak benih yang dipakai, mis. `200` (frame 5.15/5.16).
  final int jumlahBenih;

  /// Semaian yang sudah selesai tidak bisa diubah lagi (catatan alur page 05).
  final bool selesai;

  /// Semaian yang lahir saat perangkat offline menunggu sinkron; barisnya
  /// memakai lencana "Antrean" (frame 5.13).
  final bool antrean;

  /// Banyak bahan (pak) yang terpakai saat menyemai; tampil di kartu detail
  /// sebagai "Stok terpakai: Benih Romaine 2 pak" (frame 5.14–5.16).
  final int jumlahBahan;

  /// Sisa benih yang belum dipindah setelah pindah sebagian (frame 5.23).
  final int? sisaBenih;

  /// Banyak benih yang sudah dipindah ke meja (frame 5.16–5.30).
  final int? jumlahPindah;

  /// Nama meja tujuan, mis. `Meja A2` (frame 5.19–5.30).
  final String? pindahKe;

  /// Benih yang sengaja tidak dipindah saat semaian ditutup (frame 5.29).
  final int? tidakDipindah;

  /// Umur semaian dalam hari (HSS).
  int get hss => hssSemaian(tanggalSemai);

  /// Siap pindah saat umurnya genap 15 hari dan belum ditandai selesai.
  bool get siapPindah => !selesai && hss >= v2SemaianHssSiapPindah;

  V2SemaianStatus get status => selesai
      ? V2SemaianStatus.selesai
      : siapPindah
      ? V2SemaianStatus.siapPindah
      : V2SemaianStatus.berjalan;

  /// `HSS 17` (kolom kanan baris dan Value kartu detail).
  String get labelHss => 'HSS $hss';

  /// `Semai 29 Okt` (subjudul baris dan Kicker kartu detail).
  String get labelSemai => 'Semai ${labelTanggalSemai(tanggalSemai)}';

  /// `Romaine, 200 benih` atau `Romaine, sisa 80 dari 200 benih` (kartu detail).
  String get labelBenih => sisaBenih == null
      ? '$nama, $jumlahBenih benih'
      : '$nama, sisa $sisaBenih dari $jumlahBenih benih';

  /// `Stok terpakai: Benih Romaine 2 pak` (baris Extra kartu detail).
  String get labelStokTerpakai =>
      'Stok terpakai: Benih $nama $jumlahBahan pak';

  /// `Sudah pindah: 120 ke Meja A3` atau `Pindah 120 ke Meja A3. 80 tidak
  /// dipindah.` (baris Extra kartu detail setelah pindah).
  String? get labelPindah {
    final jumlah = jumlahPindah;
    final meja = pindahKe;
    if (jumlah == null || meja == null) return null;
    if (tidakDipindah != null) {
      return 'Pindah $jumlah ke $meja. $tidakDipindah tidak dipindah.';
    }
    return 'Sudah pindah: $jumlah ke $meja';
  }

  /// Sisa hari menuju HSS 15; nol saat sudah siap pindah.
  int get hariMenujuSiap =>
      v2SemaianHssSiapPindah - hss < 0 ? 0 : v2SemaianHssSiapPindah - hss;

  /// Salinan dengan sebagian kolom diganti; dipakai setelah "Ubah semaian"
  /// mengubah tanggal, jumlah benih, atau status selesai (frame 5.25–5.28).
  V2SemaianItem copyWith({
    String? id,
    String? nama,
    DateTime? tanggalSemai,
    int? jumlahBenih,
    bool? selesai,
    bool? antrean,
    int? jumlahBahan,
    int? sisaBenih,
    int? jumlahPindah,
    String? pindahKe,
    int? tidakDipindah,
  }) {
    return V2SemaianItem(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      tanggalSemai: tanggalSemai ?? this.tanggalSemai,
      jumlahBenih: jumlahBenih ?? this.jumlahBenih,
      selesai: selesai ?? this.selesai,
      antrean: antrean ?? this.antrean,
      jumlahBahan: jumlahBahan ?? this.jumlahBahan,
      sisaBenih: sisaBenih ?? this.sisaBenih,
      jumlahPindah: jumlahPindah ?? this.jumlahPindah,
      pindahKe: pindahKe ?? this.pindahKe,
      tidakDipindah: tidakDipindah ?? this.tidakDipindah,
    );
  }
}

// --- Data contoh (frame 5.1, 5.2, 5.6) -----------------------------------

/// Baris pertama frame 5.1/5.2 dan kartu detail 5.16: Romaine siap pindah,
/// semai 29 Okt (HSS 17), 200 benih.
final V2SemaianItem designSemaianRomaineSiapPindah = V2SemaianItem(
  id: 'semaian-romaine-29-okt',
  nama: 'Romaine',
  tanggalSemai: DateTime(2026, 10, 29),
  jumlahBenih: 200,
);

/// Baris kedua frame 5.1/5.2 dan kartu detail 5.15: Butterhead sedang
/// berjalan, semai 5 Nov (HSS 10), 150 benih.
final V2SemaianItem designSemaianButterhead = V2SemaianItem(
  id: 'semaian-butterhead-5-nov',
  nama: 'Butterhead',
  tanggalSemai: DateTime(2026, 11, 5),
  jumlahBenih: 150,
);

/// Baris ketiga frame 5.1/5.2: Romaine baru disemai, semai 12 Nov (HSS 3).
///
/// Jumlah benih tidak terbaca di frame; 100 dipakai sebagai contoh.
final V2SemaianItem designSemaianRomaineBaru = V2SemaianItem(
  id: 'semaian-romaine-12-nov',
  nama: 'Romaine',
  tanggalSemai: DateTime(2026, 11, 12),
  jumlahBenih: 100,
);

/// Baris frame 5.6 dan kartu detail 5.30: Romaine sudah selesai, semai 23 Okt
/// (HSS 23), 42 benih, semuanya dipindah ke Meja A2.
final V2SemaianItem designSemaianSelesai = V2SemaianItem(
  id: 'semaian-romaine-23-okt',
  nama: 'Romaine',
  tanggalSemai: DateTime(2026, 10, 23),
  jumlahBenih: 42,
  selesai: true,
  jumlahPindah: 42,
  pindahKe: 'Meja A2',
);

/// Frame 5.23: Romaine siap pindah dengan sisa 80 benih setelah 120 dipindah.
final V2SemaianItem designSemaianSisa = designSemaianRomaineSiapPindah.copyWith(
  sisaBenih: 80,
  jumlahPindah: 120,
  pindahKe: 'Meja A3',
);

/// Frame 5.19: Romaine selesai setelah semua 200 benih pindah ke Meja A2.
final V2SemaianItem designSemaianDipindahSemua =
    designSemaianRomaineSiapPindah.copyWith(
      selesai: true,
      jumlahPindah: 200,
      pindahKe: 'Meja A2',
    );

/// Frame 5.29: Romaine selesai, 120 benih pindah ke Meja A3 dan 80 ditinggal.
final V2SemaianItem designSemaianSelesaiSisa =
    designSemaianRomaineSiapPindah.copyWith(
      selesai: true,
      jumlahPindah: 120,
      pindahKe: 'Meja A3',
      tidakDipindah: 80,
    );

/// Sumber daftar semaian: tiga baris berjalan dan satu baris selesai.
///
/// Chip "Semua" menyaring baris selesai keluar (frame 5.1), sehingga frame 5.6
/// cukup memakai chip "Selesai" pada daftar yang sama.
final List<V2SemaianItem> designSemaian = <V2SemaianItem>[
  designSemaianRomaineSiapPindah,
  designSemaianButterhead,
  designSemaianRomaineBaru,
  designSemaianSelesai,
];

// --- Bahan semaian (form 5.7) --------------------------------------------

/// Satu pilihan bahan di form "Tambah semaian" (kolom "Bahan").
class V2SemaianBahan {
  const V2SemaianBahan({
    required this.nama,
    required this.stok,
    required this.satuan,
  });

  final String nama;

  /// Stok benih yang tersisa, dipakai untuk memeriksa "Jumlah bahan".
  final int stok;
  final String satuan;

  /// `12 pak` — dipakai helper "Stok hanya 12 pak" (frame 5.11).
  String get labelStok => '$stok $satuan';
}

/// Pilihan bahan form tambah semaian. Benih Romaine 12 pak seperti frame 5.7.
const List<V2SemaianBahan> designBahanSemaian = <V2SemaianBahan>[
  V2SemaianBahan(nama: 'Benih Romaine', stok: 12, satuan: 'pak'),
  V2SemaianBahan(nama: 'Benih Butterhead', stok: 2, satuan: 'pak'),
  V2SemaianBahan(nama: 'Benih Lollo Rossa', stok: 8, satuan: 'pak'),
];

/// Bahan yang terpilih saat form dibuka (frame 5.7).
final V2SemaianBahan designBahanRomaine = designBahanSemaian[0];

/// Semaian baru hasil form 5.7: Romaine disemai hari ini (HSS 0), 200 benih.
final V2SemaianItem designSemaianBaru = V2SemaianItem(
  id: 'semaian-romaine-15-nov',
  nama: 'Romaine',
  tanggalSemai: DateTime(2026, 11, 15),
  jumlahBenih: 200,
);

/// Daftar frame 5.12 setelah "Semaian ditambahkan": semaian baru di paling atas.
final List<V2SemaianItem> designSemaianDitambah = <V2SemaianItem>[
  designSemaianBaru,
  designSemaianRomaineSiapPindah,
  designSemaianButterhead,
];

/// Daftar frame 5.13 saat offline: semaian baru menunggu sinkron di paling atas,
/// lalu satu semaian siap pindah.
final List<V2SemaianItem> designSemaianAntrean = <V2SemaianItem>[
  designSemaianBaru.copyWith(antrean: true),
  designSemaianRomaineSiapPindah,
];
