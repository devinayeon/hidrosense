// Regresi BUG-44: kartu Detail semaian hanya menyebut satu bahan ("Stok
// terpakai") walau form 5.7 menyimpan beberapa baris bahan.
//
// Bukti gagal di kode lama: `v2SemaianItemFromRecord` tidak pernah mengisi
// `bahanList`, jadi label hanya memakai bahan pertama.
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/inventory_record.dart';
import 'package:hidrosense_mobile/data/models/nursery_record.dart';
import 'package:hidrosense_mobile/views/v2/connected/v2_semaian_connected.dart';

InventoryRecord _inventaris(String id, String nama, String category) =>
    InventoryRecord.fromJson({
      'id_inventaris': id,
      'public_id': null,
      'version': null,
      'id_jenis_inventaris': id,
      'id_obat': null,
      'nama_barang': nama,
      'satuan': 'pak',
      'stok_minimum': null,
      'status_aktif': 1,
      'nama_jenis': category,
      'nama_obat': null,
      'saldo': '10',
    });

void main() {
  test('semua bahan semaian tampil di "Stok terpakai" (BUG-44)', () {
    const sowing = SowingRecord(
      id: '7',
      userId: '1',
      sowingDate: '2026-11-08',
      seedCount: 200,
      status: 'aktif',
      isReadyToMove: true,
      ageDays: 17,
      materials: [
        SowingMaterialLine(inventoryId: '1', amount: '2', unit: 'pak'),
        SowingMaterialLine(inventoryId: '2', amount: '1', unit: 'liter'),
      ],
    );

    final item = v2SemaianItemFromRecord(
      sowing,
      inventaris: [
        _inventaris('1', 'Benih Romaine', 'Benih'),
        _inventaris('2', 'Nutrisi AB Mix', 'Nutrisi'),
      ],
    );

    expect(item.bahanList, hasLength(2));
    expect(item.labelStokTerpakai, contains('Romaine 2 pak'));
    expect(
      item.labelStokTerpakai,
      contains('Nutrisi AB Mix 1 liter'),
      reason: 'BUG-44: bahan kedua harus ikut tampil, bukan hanya yang pertama',
    );
  });
}