// Regresi statusStok vs aturan kanonik backend `di_bawah_minimum` (saldo <
// minimum). Sebelum perbaikan, statusStok memakai `<=` sehingga saldo sama
// dengan minimum dilabeli "Menipis", padahal kartu Beranda, label stok lama,
// dan respons backend semuanya menyebut bukan menipis.
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/inventory_record.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_inventaris_data.dart';

InventoryRecord _record({required String balance, String? minimum}) =>
    InventoryRecord.fromJson({
      'id_inventaris': '1',
      'public_id': null,
      'version': null,
      'id_jenis_inventaris': '1',
      'id_obat': null,
      'nama_barang': 'Benih Uji',
      'satuan': 'pak',
      'stok_minimum': minimum,
      'status_aktif': 1,
      'nama_jenis': 'Benih',
      'nama_obat': null,
      'saldo': balance,
    });

void main() {
  test('saldo nol habis, di bawah minimum menipis, sisanya aman', () {
    expect(statusStok(0, 3), V2InventarisStatus.habis);
    expect(statusStok(2, 3), V2InventarisStatus.menipis);
    expect(statusStok(4, 3), V2InventarisStatus.aman);
  });

  test('saldo sama dengan minimum bukan menipis (aturannya saldo < minimum)', () {
    expect(statusStok(3, 3), V2InventarisStatus.aman);
    expect(statusStok(10, 10), V2InventarisStatus.aman);
  });

  test('tanpa minimum tidak menipis', () {
    expect(statusStok(1, null), V2InventarisStatus.aman);
  });

  test('statusStok sepakat dengan InventoryRecord.isLow di batas minimum', () {
    for (final saldo in ['0', '1', '2.99', '3', '3.01', '10']) {
      final record = _record(balance: saldo, minimum: '3');
      final expected = record.balanceMinor == BigInt.zero
          ? V2InventarisStatus.habis
          : record.isLow
          ? V2InventarisStatus.menipis
          : V2InventarisStatus.aman;
      expect(
        statusStok(double.parse(saldo), 3),
        expected,
        reason: 'saldo $saldo minimum 3',
      );
    }
  });
}
