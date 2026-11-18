/// Model dan data contoh alur "04 Inventaris".
///
/// Satu barang punya dua hal yang berbeda: jenisnya ([V2JenisBarang], dipakai
/// untuk saringan dan ikon lead) dan keadaan stoknya ([V2InventarisStatus],
/// yang menentukan badge "Menipis"/"Habis" di baris). Label pendek jenis
/// dipakai di baris daftar, sedangkan label penuh dipakai di sheet 4.7.
library;

import '../../../core/formatting.dart';

/// Jenis barang yang bisa disaring di halaman Stok (sheet 4.7).
enum V2JenisBarang {
  benih('Benih', 'Benih'),
  nutrisi('Nutrisi', 'Nutrisi'),
  media('Media', 'Media tanam'),
  obat('Obat', 'Obat');

  const V2JenisBarang(this.label, this.sheetLabel);

  /// Label pendek di baris daftar, mis. `Media`.
  final String label;

  /// Label penuh di sheet "Jenis barang", mis. `Media tanam`.
  final String sheetLabel;
}

/// Keadaan stok satu barang; menentukan badge di baris (frame 4.1).
enum V2InventarisStatus { aman, menipis, habis }

/// Keadaan stok dari jumlah vs stok minimum: nol berarti habis, menyentuh
/// minimum berarti menipis, sisanya aman.
///
/// Dipakai setelah "Catat stok" mengubah jumlah supaya badge ikut pindah
/// (frame 4.23 tetap "Cukup" karena 10 masih di atas minimum 3).
V2InventarisStatus statusStok(double jumlah, double? minimum) {
  if (jumlah <= 0) return V2InventarisStatus.habis;
  if (minimum != null && jumlah <= minimum) return V2InventarisStatus.menipis;
  return V2InventarisStatus.aman;
}

/// Riwayat yang tampil di kartu detail: paling banyak 3 entri terbaru.
///
/// Frame 4.23 menampilkan "Hari ini", "14 Nov", "10 Nov" — entri "7 Nov" yang
/// ada di frame 4.19 keluar setelah satu catatan baru masuk. Jadi riwayat lama
/// tetap disimpan, hanya tampilannya dibatasi tiga baris.
List<V2InventarisRiwayat> riwayatTampil(List<V2InventarisRiwayat> riwayat) =>
    riwayat.length <= 3 ? riwayat : riwayat.sublist(0, 3);

/// Satu keluaran/masukan stok di kartu "Riwayat" halaman detail (frame 4.19).
class V2InventarisRiwayat {
  const V2InventarisRiwayat(this.label, this.tanggal);

  /// Mis. `Pakai 2 pak` atau `Masuk 10 pak`.
  final String label;

  /// Mis. `14 Nov`, `Hari ini`.
  final String tanggal;
}

/// Satu baris stok.
class V2InventarisItem {
  const V2InventarisItem({
    required this.id,
    required this.nama,
    required this.jenis,
    required this.jumlah,
    required this.satuan,
    this.status = V2InventarisStatus.aman,
    this.arsip = false,
    this.antrean = false,
    this.minimum,
    this.riwayat = const <V2InventarisRiwayat>[],
  });

  final String id;
  final String nama;
  final V2JenisBarang jenis;
  final double jumlah;

  /// Satuan yang ditulis apa adanya, mis. `pak`, `kg`, `lembar`.
  final String satuan;
  final V2InventarisStatus status;

  /// Barang yang sudah diarsipkan; hanya muncul saat saringan `Arsip`.
  final bool arsip;

  /// Barang baru yang belum tersinkron; badge "Antrean" menggantikan badge
  /// keadaan (frame 4.16).
  final bool antrean;

  /// Stok minimum yang dipakai untuk memutuskan "Menipis"; null berarti belum
  /// diisi (halaman detail memakai ini sebagai baris meta).
  final double? minimum;

  /// Riwayat keluar-masukan barang, terbaru dulu (frame 4.17–4.20, 4.29).
  final List<V2InventarisRiwayat> riwayat;

  /// `12 pak`, `8 kg` (kolom kanan baris).
  String get kuantitas => '${formatAngka(jumlah)} $satuan';

  /// `Minimum 3 pak`; null saat stok minimum belum diisi.
  String? get minimumLabel =>
      minimum == null ? null : 'Minimum ${formatAngka(minimum!)} $satuan';

  /// Salinan dengan sebagian kolom diganti; dipakai setelah "Catat stok"
  /// memperbarui jumlah, keadaan, dan menambah baris riwayat (frame 4.23).
  V2InventarisItem copyWith({
    String? id,
    String? nama,
    V2JenisBarang? jenis,
    double? jumlah,
    String? satuan,
    V2InventarisStatus? status,
    bool? arsip,
    bool? antrean,
    double? minimum,
    List<V2InventarisRiwayat>? riwayat,
  }) {
    return V2InventarisItem(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      jenis: jenis ?? this.jenis,
      jumlah: jumlah ?? this.jumlah,
      satuan: satuan ?? this.satuan,
      status: status ?? this.status,
      arsip: arsip ?? this.arsip,
      antrean: antrean ?? this.antrean,
      minimum: minimum ?? this.minimum,
      riwayat: riwayat ?? this.riwayat,
    );
  }
}

/// Label tombol saring jenis: `Jenis` saat belum dipilih, `Jenis: Benih` saat
/// salah satu jenis dipilih (frame 4.8/4.9).
String labelChipJenis(V2JenisBarang? jenis) =>
    jenis == null ? 'Jenis' : 'Jenis: ${jenis.label}';

/// Saringan keadaan yang saling meniadakan (frame 4.1).
const List<String> labelChipStatus = <String>['Semua', 'Menipis', 'Arsip'];

/// Pilihan di sheet "Jenis barang" (frame 4.7); `null` berarti `Semua`.
const List<(String, V2JenisBarang?)> pilihanJenis = <(String, V2JenisBarang?)>[
  ('Semua', null),
  ('Benih', V2JenisBarang.benih),
  ('Media tanam', V2JenisBarang.media),
  ('Nutrisi', V2JenisBarang.nutrisi),
  ('Obat', V2JenisBarang.obat),
];

/// Urutan chip jenis di form "Tambah barang" (frame 4.10): Benih, Media,
/// Nutrisi, Obat.
const List<V2JenisBarang> urutanJenisForm = <V2JenisBarang>[
  V2JenisBarang.benih,
  V2JenisBarang.media,
  V2JenisBarang.nutrisi,
  V2JenisBarang.obat,
];

/// Pilihan di sheet "Pilih obat" (frame 4.12).
const List<String> designObat = <String>[
  'Pestisida nabati',
  'Sabun insektisida',
  'Fungisida organik',
];

/// Contoh isian form "Tambah barang": (nama barang, satuan). Frame 4.10 memakai
/// Benih dan frame 4.11 memakai Obat; jenis lain memakai contoh yang sepadan.
(String, String) hintFormBarang(V2JenisBarang jenis) => switch (jenis) {
  V2JenisBarang.benih => ('Contoh: Benih Romaine', 'Contoh: pak, kg, botol'),
  V2JenisBarang.media => ('Contoh: Rockwool', 'Contoh: lembar, blok'),
  V2JenisBarang.nutrisi => ('Contoh: Nutrisi AB Mix', 'Contoh: kg, liter'),
  V2JenisBarang.obat => ('Contoh: Pestisida Nabati', 'Contoh: botol'),
};

// --- Data contoh halaman detail (frame 4.17–4.20, 4.29) -------------------

/// Riwayat keluar-masukan Benih Romaine (frame 4.19 dan 4.29).
const List<V2InventarisRiwayat> _riwayatRomaine = <V2InventarisRiwayat>[
  V2InventarisRiwayat('Pakai 2 pak', '14 Nov'),
  V2InventarisRiwayat('Masuk 10 pak', '10 Nov'),
  V2InventarisRiwayat('Pakai 1 pak', '7 Nov'),
];

/// Frame `4.17 Detail barang baru`: Benih Lollo Rossa baru masuk hari ini.
const V2InventarisItem designDetailBaru = V2InventarisItem(
  id: 'stok-benih-lollo-rossa',
  nama: 'Benih Lollo Rossa',
  jenis: V2JenisBarang.benih,
  jumlah: 8,
  satuan: 'pak',
  minimum: 3,
  riwayat: <V2InventarisRiwayat>[
    V2InventarisRiwayat('Masuk 8 pak', 'Hari ini'),
  ],
);

/// Frame `4.18 Detail barang menipis`: Benih Butterhead tinggal 2 pak.
const V2InventarisItem designDetailMenipis = V2InventarisItem(
  id: 'stok-benih-butterhead',
  nama: 'Benih Butterhead',
  jenis: V2JenisBarang.benih,
  jumlah: 2,
  satuan: 'pak',
  status: V2InventarisStatus.menipis,
  minimum: 3,
  riwayat: <V2InventarisRiwayat>[
    V2InventarisRiwayat('Pakai 3 pak', '14 Nov'),
    V2InventarisRiwayat('Masuk 5 pak', '1 Nov'),
    V2InventarisRiwayat('Pakai 2 pak', '28 Okt'),
  ],
);

/// Frame `4.19 Detail barang`: Benih Romaine stoknya cukup.
const V2InventarisItem designDetailBiasa = V2InventarisItem(
  id: 'stok-benih-romaine',
  nama: 'Benih Romaine',
  jenis: V2JenisBarang.benih,
  jumlah: 12,
  satuan: 'pak',
  minimum: 3,
  riwayat: _riwayatRomaine,
);

/// Frame `4.23 Stok tercatat`: Benih Romaine setelah dipakai 2 pak (12 jadi 10).
/// Tiga baris riwayat terbaru; entri "7 Nov" di frame 4.19 sudah keluar.
const V2InventarisItem designDetailTercatat = V2InventarisItem(
  id: 'stok-benih-romaine',
  nama: 'Benih Romaine',
  jenis: V2JenisBarang.benih,
  jumlah: 10,
  satuan: 'pak',
  minimum: 3,
  riwayat: <V2InventarisRiwayat>[
    V2InventarisRiwayat('Pakai 2 pak', 'Hari ini'),
    V2InventarisRiwayat('Pakai 2 pak', '14 Nov'),
    V2InventarisRiwayat('Masuk 10 pak', '10 Nov'),
  ],
);

/// Frame `4.20 Detail barang habis`: Rockwool ludes.
const V2InventarisItem designDetailHabis = V2InventarisItem(
  id: 'stok-rockwool',
  nama: 'Rockwool',
  jenis: V2JenisBarang.media,
  jumlah: 0,
  satuan: 'lembar',
  status: V2InventarisStatus.habis,
  minimum: 10,
  riwayat: <V2InventarisRiwayat>[
    V2InventarisRiwayat('Pakai 10 lembar', '14 Nov'),
    V2InventarisRiwayat('Pakai 30 lembar', '10 Nov'),
    V2InventarisRiwayat('Masuk 80 lembar', '1 Nov'),
  ],
);

/// Frame `4.29 Detail barang arsip`: Benih Romaine sudah diarsipkan.
const V2InventarisItem designDetailArsip = V2InventarisItem(
  id: 'stok-benih-romaine',
  nama: 'Benih Romaine',
  jenis: V2JenisBarang.benih,
  jumlah: 12,
  satuan: 'pak',
  arsip: true,
  minimum: 3,
  riwayat: _riwayatRomaine,
);

// --- Data contoh (frame 4.1, 4.8, 4.9) ------------------------------------

/// Empat baris frame 4.1/4.2/4.7: dua benih, satu nutrisi, satu media.
final List<V2InventarisItem> designInventaris = <V2InventarisItem>[
  designDetailBiasa,
  designDetailMenipis,
  const V2InventarisItem(
    id: 'stok-nutrisi-ab-mix',
    nama: 'Nutrisi AB Mix',
    jenis: V2JenisBarang.nutrisi,
    jumlah: 8,
    satuan: 'kg',
  ),
  designDetailHabis,
];

/// Tiga baris frame 4.15 "Barang ditambahkan": barang baru `Benih Lollo Rossa`
/// duduk paling atas.
const List<V2InventarisItem> designInventarisDitambah = <V2InventarisItem>[
  V2InventarisItem(
    id: 'stok-benih-lollo-rossa',
    nama: 'Benih Lollo Rossa',
    jenis: V2JenisBarang.benih,
    jumlah: 8,
    satuan: 'pak',
  ),
  V2InventarisItem(
    id: 'stok-benih-romaine',
    nama: 'Benih Romaine',
    jenis: V2JenisBarang.benih,
    jumlah: 12,
    satuan: 'pak',
  ),
  V2InventarisItem(
    id: 'stok-benih-butterhead',
    nama: 'Benih Butterhead',
    jenis: V2JenisBarang.benih,
    jumlah: 2,
    satuan: 'pak',
    status: V2InventarisStatus.menipis,
  ),
];

/// Dua baris frame 4.16 "Tersimpan di HP": barang baru masih menunggu sinkron
/// (badge "Antrean").
const List<V2InventarisItem> designInventarisAntrean = <V2InventarisItem>[
  V2InventarisItem(
    id: 'stok-benih-lollo-rossa',
    nama: 'Benih Lollo Rossa',
    jenis: V2JenisBarang.benih,
    jumlah: 8,
    satuan: 'pak',
    antrean: true,
  ),
  V2InventarisItem(
    id: 'stok-benih-romaine',
    nama: 'Benih Romaine',
    jenis: V2JenisBarang.benih,
    jumlah: 12,
    satuan: 'pak',
  ),
];
