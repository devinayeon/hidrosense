import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/inventory_record.dart';

Map<String, dynamic> master() => {
  'id_inventaris': '9223372036854775807',
  'public_id': null,
  'version': null,
  'id_jenis_inventaris': '2',
  'id_obat': null,
  'nama_barang': 'Benih',
  'satuan': 'gram',
  'stok_minimum': '10.50',
  'status_aktif': 1,
  'nama_jenis': 'Bibit',
  'nama_obat': null,
};

void main() {
  test('signed64 IDs and exact decimal values survive cache round trip', () {
    final record = InventoryRecord.fromApi(master(), {
      'id_inventaris': '9223372036854775807',
      'satuan': 'gram',
      'stok_minimum': '10.5',
      'saldo': '00010.49',
      'di_bawah_minimum': true,
    });
    expect(record.id, '9223372036854775807');
    expect(record.balance, '10.49');
    expect(record.minimum, '10.5');
    expect(record.balanceMinor, BigInt.from(1049));
    expect(record.isLow, isTrue);
    expect(InventoryRecord.fromJson(record.toJson()).toJson(), record.toJson());
    final maximum = InventoryRecord.fromJson({
      ...master(),
      'saldo': '9999999999.99',
    });
    expect(maximum.balanceMinor, BigInt.parse('999999999999'));
  });

  test(
    'reject numeric IDs, overflow, numeric/negative/inexact decimals and bad status',
    () {
      for (final change in <Map<String, dynamic>>[
        {'id_inventaris': 1},
        {'id_inventaris': '9223372036854775808'},
        {'id_jenis_inventaris': '01'},
        {'saldo': 1.5},
        {'saldo': '-1'},
        {'saldo': '1.001'},
        {'saldo': '1e2'},
        {'status_aktif': true},
        {'stok_minimum': '0'},
        {'public_id': 'broken', 'version': '1'},
        {'public_id': null, 'version': '1'},
      ]) {
        expect(
          () =>
              InventoryRecord.fromJson({...master(), 'saldo': '0', ...change}),
          throwsFormatException,
          reason: '$change',
        );
      }
    },
  );

  test('master and balance mismatch is rejected, equality is not low', () {
    final balance = {
      'id_inventaris': '9223372036854775807',
      'satuan': 'gram',
      'stok_minimum': '10.5',
      'saldo': '10.5',
      'di_bawah_minimum': false,
    };
    expect(InventoryRecord.fromApi(master(), balance).isLow, isFalse);
    for (final change in [
      {'id_inventaris': '2'},
      {'satuan': 'kg'},
      {'stok_minimum': '11'},
      {'di_bawah_minimum': true},
    ]) {
      expect(
        () => InventoryRecord.fromApi(master(), {...balance, ...change}),
        throwsFormatException,
      );
    }
  });
}
