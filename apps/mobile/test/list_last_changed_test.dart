import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/harvest_record.dart';
import 'package:hidrosense_mobile/data/models/sale_record.dart';
import 'package:hidrosense_mobile/models/penjualan_model.dart';
import 'package:hidrosense_mobile/viewmodels/penjualan_mappers.dart';

import 'support/harvest_fixture.dart';
import 'support/sales_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('record panen dan penjualan membaca updated_at dari server', () {
    final harvest = HarvestRecord.fromJson(
      harvestJson(updatedAt: 1700000000000),
    );
    expect(harvest.updatedAt, 1700000000000);

    final sale = SaleRecord.fromJson(saleJson(updatedAt: 1700000000001));
    expect(sale.updatedAt, 1700000000001);
    expect(toPenjualanItem(sale).updatedAt, 1700000000001);
  });

  test('daftar panen menaruh yang paling baru diubah di atas, bukan tanggal', () async {
    final repo = await loadedRepo();
    repo.records = [
      HarvestRecord.fromJson(
        harvestJson(id: '1', date: '2026-10-20', updatedAt: 100),
      ),
      HarvestRecord.fromJson(
        harvestJson(id: '2', date: '2026-10-01', updatedAt: 200),
      ),
    ];
    final vm = harvestVm(repo);
    addTearDown(vm.dispose);
    await vm.refresh();
    // id 2 diubah paling akhir walau tanggal panennya lebih lama.
    expect(vm.current.records.map((record) => record.id).toList(), [
      '2',
      '1',
    ]);
  });

  test('daftar penjualan menaruh yang paling baru diubah di atas, bukan tanggal', () {
    PenjualanItem item(String id, String date, int? updatedAt) => PenjualanItem(
      id: id,
      pembeli: 'Pembeli $id',
      tanggal: date,
      tanggalIso: date,
      kuantitas: '1 Kg',
      totalHarga: 1000,
      status: StatusPenjualan.lunas,
      updatedAt: updatedAt,
    );
    final items = [
      item('1', '2026-10-20', 100),
      item('2', '2026-10-01', 200),
    ]..sort(comparePenjualanItems);
    expect(items.map((sale) => sale.id).toList(), ['2', '1']);
  });

  test('tanpa updated_at, daftar penjualan kembali ke tanggal lalu id', () {
    PenjualanItem item(String id, String date, int? updatedAt) => PenjualanItem(
      id: id,
      pembeli: 'Pembeli $id',
      tanggal: date,
      tanggalIso: date,
      kuantitas: '1 Kg',
      totalHarga: 1000,
      status: StatusPenjualan.lunas,
      updatedAt: updatedAt,
    );
    final items = [
      item('2', '2026-10-01', null),
      item('1', '2026-10-20', null),
    ]..sort(comparePenjualanItems);
    expect(items.map((sale) => sale.id).toList(), ['1', '2']);
  });
}