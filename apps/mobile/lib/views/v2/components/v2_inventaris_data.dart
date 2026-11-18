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

  /// `12 pak`, `8 kg` (kolom kanan baris).
  String get kuantitas => '${formatAngka(jumlah)} $satuan';
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

// --- Data contoh (frame 4.1, 4.8, 4.9) ------------------------------------

/// Empat baris frame 4.1/4.2/4.7: dua benih, satu nutrisi, satu media.
final List<V2InventarisItem> designInventaris = <V2InventarisItem>[
  const V2InventarisItem(
    id: 'stok-benih-romaine',
    nama: 'Benih Romaine',
    jenis: V2JenisBarang.benih,
    jumlah: 12,
    satuan: 'pak',
  ),
  const V2InventarisItem(
    id: 'stok-benih-butterhead',
    nama: 'Benih Butterhead',
    jenis: V2JenisBarang.benih,
    jumlah: 2,
    satuan: 'pak',
    status: V2InventarisStatus.menipis,
  ),
  const V2InventarisItem(
    id: 'stok-nutrisi-ab-mix',
    nama: 'Nutrisi AB Mix',
    jenis: V2JenisBarang.nutrisi,
    jumlah: 8,
    satuan: 'kg',
  ),
  const V2InventarisItem(
    id: 'stok-rockwool',
    nama: 'Rockwool',
    jenis: V2JenisBarang.media,
    jumlah: 0,
    satuan: 'lembar',
    status: V2InventarisStatus.habis,
  ),
];
