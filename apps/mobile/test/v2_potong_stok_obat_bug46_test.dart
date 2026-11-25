// Regresi BUG-46 (D-31): stok obat tidak muncul di lembar terima rekomendasi
// karena nama jenis nyata dari server adalah "Obat & Pestisida", sedangkan
// pencocokan lama hanya menerima "obat"/"nutrisi" persis.
//
// Bukti gagal di kode lama: record berjenis "Obat & Pestisida" tidak ikut
// ditawarkan, dan `bolehPotongStokRecord` belum ada (tidak ter-compile).
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/inventory_record.dart';
import 'package:hidrosense_mobile/features/pest/presentation/widgets/decision_sheets.dart';

InventoryRecord _item(
  String id,
  String nama, {
  required String category,
  String? medicineId,
}) => InventoryRecord.fromJson({
  'id_inventaris': id,
  'public_id': null,
  'version': null,
  'id_jenis_inventaris': id,
  'id_obat': medicineId,
  'nama_barang': nama,
  'satuan': 'botol',
  'stok_minimum': null,
  'status_aktif': 1,
  'nama_jenis': category,
  'nama_obat': medicineId == null ? null : 'Abamectin',
  'saldo': '5',
});

void main() {
  test('jenis "Obat & Pestisida" dari data nyata bisa dipotong (BUG-46)', () {
    final records = [
      _item('1', 'Abamectin 18 EC', category: 'Obat & Pestisida', medicineId: '9'),
      _item('2', 'Nutrisi AB Mix', category: 'Nutrisi'),
      _item('3', 'Benih Romaine', category: 'Benih'),
      _item('4', 'Media Rockwool', category: 'Perlengkapan'),
    ];

    final opsi = stockOptionsDari(records);
    expect(
      opsi.map((row) => row.name),
      containsAll(<String>['Abamectin 18 EC', 'Nutrisi AB Mix']),
    );
    expect(opsi.map((row) => row.name), isNot(contains('Benih Romaine')));
    expect(opsi.map((row) => row.name), isNot(contains('Media Rockwool')));
  });

  test('pengenal obat stabil dipakai walau nama jenis berbeda (D-31)', () {
    final obat = _item(
      '5',
      'Produk Obat',
      category: 'Perlengkapan',
      medicineId: '11',
    );
    expect(bolehPotongStokRecord(obat), isTrue);
    expect(bolehPotongStok('Obat & Pestisida'), isTrue);
  });
}