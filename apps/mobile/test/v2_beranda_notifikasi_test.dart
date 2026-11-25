// Notifikasi Beranda harus diisi data nyata, bukan contoh: satu baris per batch
// yang siap pindah (HSS 15) plus satu ringkasan stok di bawah minimum.
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/inventory_record.dart';
import 'package:hidrosense_mobile/data/models/nursery_record.dart';
import 'package:hidrosense_mobile/views/v2/connected/v2_beranda_notifikasi.dart';

SowingRecord _sowing({String id = '1', bool ready = true, int? age = 15}) {
  return SowingRecord(
    id: id,
    userId: 'u1',
    sowingDate: '2026-01-01',
    seedCount: 100,
    status: 'aktif',
    ageDays: age,
    isReadyToMove: ready,
  );
}

InventoryRecord _rec(String saldo, {String? minimum}) {
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
    'nama_jenis': 'Benih',
    'nama_obat': null,
    'saldo': saldo,
  });
}

void main() {
  test('semaian siap pindah dan stok menipis jadi notifikasi nyata', () {
    final groups = v2BerandaNotifikasi(
      nursery: [_sowing(id: '12')],
      inventaris: [
        _rec('2', minimum: '3'), // menipis
        _rec('0'), // habis tanpa minimum tetap dihitung
        _rec('12', minimum: '3'), // aman, tidak dihitung
      ],
    );

    expect(groups, hasLength(1));
    expect(groups.single.label, 'Baru');
    expect(groups.single.items, hasLength(2));

    final semaian = groups.single.items.first;
    expect(semaian.title, 'Semaian HSS 15');
    expect(semaian.subtitle, contains('Batch #12'));
    expect(semaian.subtitle, contains('15 HSS'));

    final stok = groups.single.items.last;
    expect(stok.title, 'Stok menipis');
    expect(stok.subtitle, '2 barang di bawah minimum stok');
  });

  test('semaian belum siap dan barang aman tidak menghasilkan notifikasi', () {
    final groups = v2BerandaNotifikasi(
      nursery: [_sowing(id: '9', ready: false, age: 8)],
      inventaris: [_rec('12', minimum: '3')],
    );

    expect(groups, isEmpty);
  });

  test('tiap batch siap pindah dapat satu baris sendiri', () {
    final groups = v2BerandaNotifikasi(
      nursery: [
        _sowing(id: '12'),
        _sowing(id: '13', age: 17),
        _sowing(id: '14', ready: false, age: 5),
      ],
      inventaris: const [],
    );

    expect(groups.single.items, hasLength(2));
    expect(groups.single.items.first.subtitle, contains('Batch #12'));
    expect(groups.single.items.last.subtitle, contains('Batch #13'));
  });
}
