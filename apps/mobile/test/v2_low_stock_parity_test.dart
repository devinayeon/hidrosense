// Regresi BUG-06: angka kartu "Stok menipis" di Beranda harus sama dengan
// jumlah baris yang muncul saat kartu itu diketuk. Cakupannya: semua jenis
// barang yang berada di bawah stok minimum, termasuk yang sudah habis.
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/inventory_record.dart';
import 'package:hidrosense_mobile/viewmodels/v2_beranda_viewmodel.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_inventaris_data.dart';
import 'package:hidrosense_mobile/views/v2/connected/v2_inventaris_connected.dart';

InventoryRecord _rec(String saldo, {String? minimum, String category = 'Benih'}) {
  return InventoryRecord.fromJson({
    'id_inventaris': '7',
    'public_id': null,
    'version': null,
    'id_jenis_inventaris': '3',
    'id_obat': null,
    'nama_barang': 'Barang',
    'satuan': 'pak',
    'stok_minimum': minimum,
    'status_aktif': 1,
    'nama_jenis': category,
    'nama_obat': null,
    'saldo': saldo,
  });
}

void main() {
  test('angka kartu stok menipis sama dengan baris daftar yang dibuka', () {
    final records = <InventoryRecord>[
      _rec('12', minimum: '3'), // aman: di atas minimum
      _rec('3', minimum: '3'), // aman: tepat minimum (bukan menipis)
      _rec('2', minimum: '3'), // menipis (benih)
      _rec('0', minimum: '10', category: 'Perlengkapan'), // habis (bukan benih)
      _rec('0'), // habis tanpa minimum
    ];

    final count = berandaLowStockCount(records);
    final rows = records
        .map(v2InventarisItemFromRecord)
        .where((item) => item.status != V2InventarisStatus.aman)
        .length;

    // Kartu dan daftar yang dibuka harus menyebut cakupan yang sama.
    expect(count, rows);
    // Menipis + habis ber-minimum + habis tanpa minimum; tepat minimum aman.
    expect(count, 3);
  });
}
