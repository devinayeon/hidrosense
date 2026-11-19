/// Model dan data contoh alur "06 Meja Tanam & Pertumbuhan".
///
/// Semua angka di frame (HST 8, panen 37 hari lagi, 10 Nov, 15 Nov) diukur dari
/// satu tanggal acuan [v2MejaHariIni] supaya data contoh tidak ikut bergeser
/// saat aplikasi dibuka di hari lain.
library;

/// Tanggal acuan data contoh page 06, 15 Nov 2026.
///
/// Sama dengan acuan page 05: HST 8 dari tanam 7 Nov, panen 22 Des 37 hari
/// lagi, dan kerusakan "15 Nov" semuanya jatuh di tanggal ini.
final DateTime v2MejaHariIni = DateTime(2026, 11, 15);

/// Umur panen bawaan tanaman di meja (frame 6.21: "Panen HST 45").
const int v2MejaUmurPanenHst = 45;

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

/// `10 Nov` — hari dan bulan tanpa tahun (subjudul daftar rusak).
String labelTanggalMeja(DateTime tanggal) =>
    '${tanggal.day} ${_bulanSingkat[tanggal.month - 1]}';

/// `15 Nov 2026` — tanggal lengkap untuk isian form (frame 6.25, 6.28).
String labelTanggalLengkap(DateTime tanggal) =>
    '${labelTanggalMeja(tanggal)} ${tanggal.year}';

/// Selisih hari tanggal saja, dalam UTC, supaya jam tidak menggeser HST.
int _selisihHari(DateTime awal, DateTime akhir) {
  final a = DateTime.utc(awal.year, awal.month, awal.day);
  final b = DateTime.utc(akhir.year, akhir.month, akhir.day);
  return b.difference(a).inDays;
}

/// Keadaan meja tanam; menentukan lencana dan tombol di halaman detail.
enum V2MejaStatus {
  /// Masih punya lubang kosong; bisa ditanami (frame 6.1, 6.10, 6.11).
  tersedia,

  /// Semua lubang terisi; tanaman baru ditolak (frame 6.1, 6.16, 6.17).
  penuh,

  /// Sedang dirawat; tanaman baru ditolak (frame 6.13).
  perawatan,
}

/// Label lencana dan chip saringan untuk setiap keadaan meja.
extension V2MejaStatusLabel on V2MejaStatus {
  String get label => switch (this) {
    V2MejaStatus.tersedia => 'Tersedia',
    V2MejaStatus.penuh => 'Penuh',
    V2MejaStatus.perawatan => 'Perawatan',
  };
}

/// Saringan daftar meja (frame 6.1).
const List<String> labelChipMeja = <String>[
  'Semua',
  'Tersedia',
  'Penuh',
  'Perawatan',
];

/// Satu jenis tanaman yang sedang tumbuh di sebuah meja.
///
/// Satu meja bisa memuat beberapa baris tanaman (frame 6.16 punya dua baris
/// Romaine dengan tanggal panen berbeda).
class V2TanamanItem {
  const V2TanamanItem({
    required this.varietas,
    required this.tanggalTanam,
    required this.tanggalPanen,
    required this.tanggalPindah,
    this.umurPanenHst = v2MejaUmurPanenHst,
    this.hssPindah = 15,
    this.jumlahAktif = 40,
    this.jumlahAwal = 42,
    this.keterangan,
    this.transferId,
  });

  /// Nama benih, mis. `Romaine`.
  final String varietas;

  /// Tanggal tanam di meja; HST dihitung dari sini.
  final DateTime tanggalTanam;

  /// Perkiraan tanggal panen; `Siap panen hari ini` saat jatuh di hari ini.
  final DateTime tanggalPanen;

  /// Tanggal tanaman dipindah dari semaian (frame 6.21).
  final DateTime tanggalPindah;

  /// Umur panen dalam hari setelah tanam (frame 6.21: 45).
  final int umurPanenHst;

  /// HSS saat dipindah dari semaian (frame 6.21: 15).
  final int hssPindah;

  /// Tanaman yang masih hidup (frame 6.21: "40 dari 42").
  final int jumlahAktif;

  /// Tanaman saat dipindah, sebelum ada yang rusak (frame 6.21: 42).
  final int jumlahAwal;

  /// Catatan bebas, mis. `Rak bawah` (frame 6.22).
  final String? keterangan;

  /// Identitas batch pemindahan backend; null untuk data contoh galeri.
  ///
  /// Dipakai untuk menyimpan catatan tanaman lewat
  /// `PATCH /api/v1/pemindahan/:id` (frame 6.22/6.23).
  final String? transferId;

  /// Umur tanaman dalam hari setelah tanam (HST).
  int get hst => _selisihHari(tanggalTanam, v2MejaHariIni);

  /// Sisa hari menuju panen; nol atau negatif berarti sudah waktunya panen.
  int get hariMenujuPanen => _selisihHari(v2MejaHariIni, tanggalPanen);

  /// `Siap panen hari ini` atau `Panen 22 Des` (subjudul baris tanaman).
  String get labelPanen => hariMenujuPanen <= 0
      ? 'Siap panen hari ini'
      : 'Panen ${labelTanggalMeja(tanggalPanen)}';

  /// `Panen 22 Des. 37 hari lagi.` (baris Extra kartu ringkasan 6.21).
  String get labelPanenLengkap => hariMenujuPanen <= 0
      ? 'Siap panen hari ini.'
      : 'Panen ${labelTanggalMeja(tanggalPanen)}. '
            '$hariMenujuPanen hari lagi.';

  /// `HST 8` (Value kartu ringkasan 6.21).
  String get labelHst => 'HST $hst';

  /// `7 Nov 2026, HSS 15` (baris Info kartu 6.21).
  String get labelPindah =>
      '${labelTanggalLengkap(tanggalPindah)}, HSS $hssPindah';

  /// `40 dari 42` (baris Info jumlah tanaman aktif).
  String get labelAktif => '$jumlahAktif dari $jumlahAwal';

  V2TanamanItem copyWith({
    String? varietas,
    DateTime? tanggalTanam,
    DateTime? tanggalPanen,
    DateTime? tanggalPindah,
    int? umurPanenHst,
    int? hssPindah,
    int? jumlahAktif,
    int? jumlahAwal,
    String? keterangan,
    String? transferId,
  }) {
    return V2TanamanItem(
      varietas: varietas ?? this.varietas,
      tanggalTanam: tanggalTanam ?? this.tanggalTanam,
      tanggalPanen: tanggalPanen ?? this.tanggalPanen,
      tanggalPindah: tanggalPindah ?? this.tanggalPindah,
      umurPanenHst: umurPanenHst ?? this.umurPanenHst,
      hssPindah: hssPindah ?? this.hssPindah,
      jumlahAktif: jumlahAktif ?? this.jumlahAktif,
      jumlahAwal: jumlahAwal ?? this.jumlahAwal,
      keterangan: keterangan ?? this.keterangan,
      transferId: transferId ?? this.transferId,
    );
  }
}

/// Satu catatan kerusakan tanaman (frame 6.24–6.29).
class V2KerusakanItem {
  const V2KerusakanItem({
    required this.jumlah,
    required this.jenis,
    required this.tanggal,
    required this.varietas,
    required this.meja,
    this.keterangan,
    this.id,
    this.transferId,
  });

  /// Identitas laporan backend; null untuk catatan contoh galeri.
  final String? id;

  /// Batch pemindahan yang punya laporan ini (`id_pemindahan`).
  final String? transferId;

  /// Banyak tanaman yang rusak, mis. `2`.
  final int jumlah;

  /// Jenis kerusakan: `Busuk akar`, `Layu`, `Hama`, atau `Lainnya`.
  final String jenis;

  /// Tanggal kejadian (frame 6.25: 15 Nov 2026).
  final DateTime tanggal;

  final String varietas;

  /// Nama meja tanpa awalan, mis. `A2`.
  final String meja;

  /// Catatan bebas, mis. `Akar berlendir` (frame 6.28).
  final String? keterangan;

  /// `2 tanaman, busuk akar` (judul baris).
  String get judul => '$jumlah tanaman, ${jenis.toLowerCase()}';

  /// `10 Nov. Romaine, Meja A2` (subjudul baris).
  String get subjudul => '${labelTanggalMeja(tanggal)}. $varietas, Meja $meja';

  V2KerusakanItem copyWith({
    int? jumlah,
    String? jenis,
    DateTime? tanggal,
    String? varietas,
    String? meja,
    String? keterangan,
    String? id,
    String? transferId,
  }) {
    return V2KerusakanItem(
      jumlah: jumlah ?? this.jumlah,
      jenis: jenis ?? this.jenis,
      tanggal: tanggal ?? this.tanggal,
      varietas: varietas ?? this.varietas,
      meja: meja ?? this.meja,
      keterangan: keterangan ?? this.keterangan,
      id: id ?? this.id,
      transferId: transferId ?? this.transferId,
    );
  }
}

/// Satu meja tanam beserta tanaman dan catatan kerusakannya.
class V2MejaItem {
  const V2MejaItem({
    this.id,
    required this.kode,
    required this.jumlahLubang,
    required this.terisi,
    required this.status,
    this.keterangan,
    this.tanaman = const <V2TanamanItem>[],
    this.rusak = const <V2KerusakanItem>[],
    this.antrean = false,
  });

  /// Identitas meja backend; null untuk data contoh galeri.
  final String? id;

  /// Kode tanpa awalan, mis. `A2`; judul baris dibentuk `Meja A2`.
  final String kode;

  final int jumlahLubang;
  final int terisi;
  final V2MejaStatus status;

  /// Catatan bebas, mis. `Dekat pintu` (form ubah 6.18).
  final String? keterangan;

  final List<V2TanamanItem> tanaman;
  final List<V2KerusakanItem> rusak;

  /// Meja yang lahir saat perangkat offline menunggu sinkron; barisnya memakai
  /// lencana "Antrean" (frame 6.9).
  final bool antrean;

  String get nama => 'Meja $kode';

  /// Lubang yang belum terisi (frame 6.10/6.11: "Kosong 200").
  int get kosong => jumlahLubang - terisi;

  /// `40/240` (kolom kanan baris).
  String get labelRasio => '$terisi/$jumlahLubang';

  /// `40 dari 240 lubang terisi` (baris ringkas kartu grid).
  String get labelTerisi => '$terisi dari $jumlahLubang lubang terisi';

  /// Meja menerima tanaman baru hanya saat tersedia dan masih ada lubang.
  bool get bisaTambahTanaman => status == V2MejaStatus.tersedia && kosong > 0;

  /// Salinan dengan sebagian kolom diganti; dipakai setelah "Ubah meja" atau
  /// "Ubah status" (frame 6.13, 6.20).
  V2MejaItem copyWith({
    String? id,
    String? kode,
    int? jumlahLubang,
    int? terisi,
    V2MejaStatus? status,
    String? keterangan,
    List<V2TanamanItem>? tanaman,
    List<V2KerusakanItem>? rusak,
    bool? antrean,
  }) {
    return V2MejaItem(
      id: id ?? this.id,
      kode: kode ?? this.kode,
      jumlahLubang: jumlahLubang ?? this.jumlahLubang,
      terisi: terisi ?? this.terisi,
      status: status ?? this.status,
      keterangan: keterangan ?? this.keterangan,
      tanaman: tanaman ?? this.tanaman,
      rusak: rusak ?? this.rusak,
      antrean: antrean ?? this.antrean,
    );
  }
}

// --- Data contoh ---------------------------------------------------------

/// Tanaman Romaine di Meja A2: tanam 7 Nov, HST 8, panen 22 Des (37 hari lagi),
/// 40 dari 42 aktif (frame 6.11, 6.21, 6.23).
final V2TanamanItem designTanamanRomaineA2 = V2TanamanItem(
  varietas: 'Romaine',
  tanggalTanam: DateTime(2026, 11, 7),
  tanggalPanen: DateTime(2026, 12, 22),
  tanggalPindah: DateTime(2026, 11, 7),
  keterangan: 'Rak bawah',
);

/// Baris Romaine kedua di Meja A2 saat penuh, panen 30 Des (frame 6.16).
final V2TanamanItem designTanamanRomaineA2Kedua = designTanamanRomaineA2
    .copyWith(
      tanggalTanam: DateTime(2026, 11, 15),
      tanggalPanen: DateTime(2026, 12, 30),
    );

/// Tanaman Romaine di Meja B1 yang siap dipanen hari ini (frame 6.17).
final V2TanamanItem designTanamanRomaineB1 = V2TanamanItem(
  varietas: 'Romaine',
  tanggalTanam: DateTime(2026, 10, 1),
  tanggalPanen: DateTime(2026, 11, 15),
  tanggalPindah: DateTime(2026, 9, 20),
);

/// Kerusakan di Meja A2: 2 tanaman busuk akar pada 10 Nov (frame 6.24, 6.29).
final V2KerusakanItem designKerusakanBusukAkar = V2KerusakanItem(
  jumlah: 2,
  jenis: 'Busuk akar',
  tanggal: DateTime(2026, 11, 10),
  varietas: 'Romaine',
  meja: 'A2',
  keterangan: 'Akar berlendir',
);

/// Kerusakan baru setelah dicatat 15 Nov (frame 6.27).
final V2KerusakanItem designKerusakanLayu = V2KerusakanItem(
  jumlah: 2,
  jenis: 'Layu',
  tanggal: DateTime(2026, 11, 15),
  varietas: 'Romaine',
  meja: 'A2',
);

/// Baris Meja A2 di daftar dan kartu detail 6.11/6.12/6.13/6.20.
final V2MejaItem designMejaA2 = V2MejaItem(
  kode: 'A2',
  jumlahLubang: 240,
  terisi: 40,
  status: V2MejaStatus.tersedia,
  keterangan: 'Dekat pintu',
  tanaman: <V2TanamanItem>[designTanamanRomaineA2],
  rusak: <V2KerusakanItem>[designKerusakanBusukAkar],
);

/// Baris Meja A3 di daftar: 120 dari 240 lubang terisi (frame 6.1/6.2).
final V2MejaItem designMejaA3 = V2MejaItem(
  kode: 'A3',
  jumlahLubang: 240,
  terisi: 120,
  status: V2MejaStatus.tersedia,
);

/// Baris Meja B1 di daftar: penuh, satu tanaman siap panen (frame 6.1/6.17).
final V2MejaItem designMejaB1 = V2MejaItem(
  kode: 'B1',
  jumlahLubang: 240,
  terisi: 240,
  status: V2MejaStatus.penuh,
  tanaman: <V2TanamanItem>[designTanamanRomaineB1],
);

/// Meja baru yang dibuat dari form tambah: C1, 180 lubang (frame 6.5, 6.8).
final V2MejaItem designMejaC1 = V2MejaItem(
  kode: 'C1',
  jumlahLubang: 180,
  terisi: 0,
  status: V2MejaStatus.tersedia,
);

/// Meja A2 setelah diubah menjadi penuh: 240/240, dua baris Romaine (6.16).
final V2MejaItem designMejaA2Penuh = designMejaA2.copyWith(
  terisi: 240,
  status: V2MejaStatus.penuh,
  tanaman: <V2TanamanItem>[designTanamanRomaineA2, designTanamanRomaineA2Kedua],
);

/// Meja A2 setelah status diubah ke Perawatan (frame 6.13).
final V2MejaItem designMejaA2Perawatan = designMejaA2.copyWith(
  status: V2MejaStatus.perawatan,
);

/// Daftar meja 6.1/6.2: A2, A3, lalu B1 yang penuh.
final List<V2MejaItem> designDaftarMeja = <V2MejaItem>[
  designMejaA2,
  designMejaA3,
  designMejaB1,
];

/// Daftar meja 6.8 setelah Meja C1 ditambahkan di paling atas.
final List<V2MejaItem> designDaftarMejaBaru = <V2MejaItem>[
  designMejaC1,
  designMejaA2,
  designMejaA3,
];

/// Daftar meja 6.9: C1 masih menunggu sinkron, A2 sudah tersimpan.
final List<V2MejaItem> designDaftarMejaOffline = <V2MejaItem>[
  designMejaC1.copyWith(antrean: true),
  designMejaA2,
];

/// Daftar rusak 6.24/6.29: satu catatan busuk akar.
final List<V2KerusakanItem> designDaftarRusak = <V2KerusakanItem>[
  designKerusakanBusukAkar,
];

/// Daftar rusak 6.27: layu 15 Nov di atas busuk akar 10 Nov.
final List<V2KerusakanItem> designDaftarRusakSetelahCatat = <V2KerusakanItem>[
  designKerusakanLayu,
  designKerusakanBusukAkar,
];
