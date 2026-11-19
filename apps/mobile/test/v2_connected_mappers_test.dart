import 'package:flutter_test/flutter_test.dart';

import 'package:hidrosense_mobile/data/models/damage_record.dart';
import 'package:hidrosense_mobile/data/models/harvest_record.dart';
import 'package:hidrosense_mobile/data/models/inventory_record.dart';
import 'package:hidrosense_mobile/data/models/nursery_record.dart';
import 'package:hidrosense_mobile/data/models/table_record.dart';
import 'package:hidrosense_mobile/data/models/transfer_record.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_meja_data.dart';
import 'package:hidrosense_mobile/views/v2/connected/v2_meja_connected.dart';
import 'package:hidrosense_mobile/views/v2/connected/v2_panen_connected.dart';
import 'package:hidrosense_mobile/views/v2/connected/v2_rawat_connected.dart';

TableRecord _table({
  String id = '1',
  String code = 'A2',
  int holes = 240,
  String status = 'tersedia',
  int plants = 40,
}) => TableRecord(
  id: id,
  code: code,
  holeCount: holes,
  status: status,
  activePlants: plants,
  availableCapacity: holes - plants,
);

TransferRecord _transfer({
  String id = '10',
  String tableId = '1',
  String sowingId = '7',
  int plants = 40,
  int active = 40,
  int? remaining,
  String? harvestDate,
}) => TransferRecord(
  id: id,
  tableId: tableId,
  sowingId: sowingId,
  transferDate: '2026-11-01',
  plantCount: plants,
  activePlants: active,
  remainingHarvestDays: remaining,
  estimatedHarvestDate: harvestDate,
  hss: 15,
  hst: 10,
);

SowingRecord _sowing({String id = '7', String materialId = '3'}) =>
    SowingRecord(
      id: id,
      userId: '1',
      sowingDate: '2026-10-17',
      seedCount: 42,
      status: 'aktif',
      isReadyToMove: true,
      materials: [
        SowingMaterialLine(inventoryId: materialId, amount: '2', unit: 'gram'),
      ],
    );

InventoryRecord _inventory({String id = '3', String name = 'Benih Romaine'}) =>
    InventoryRecord.fromJson({
      'id_inventaris': id,
      'public_id': null,
      'version': null,
      'id_jenis_inventaris': '1',
      'id_obat': null,
      'nama_barang': name,
      'satuan': 'gram',
      'stok_minimum': '1',
      'status_aktif': 1,
      'nama_jenis': 'Benih',
      'nama_obat': null,
      'saldo': '100',
    });

HarvestWeight _kg(String value) => HarvestWeight.parse(value);

void main() {
  group('v2StatusMeja', () {
    test('memetakan status backend ke tiga keadaan desain', () {
      expect(v2StatusMeja(_table(status: 'tersedia')), V2MejaStatus.tersedia);
      expect(v2StatusMeja(_table(status: 'penuh')), V2MejaStatus.penuh);
      expect(
        v2StatusMeja(_table(status: 'pemeliharaan')),
        V2MejaStatus.perawatan,
      );
      expect(v2StatusMeja(_table(status: 'nonaktif')), V2MejaStatus.perawatan);
    });
  });

  group('v2MejaItemFromRecord', () {
    test('membawa kode, lubang, dan tanaman dari batch aktif', () {
      final item = v2MejaItemFromRecord(
        _table(),
        transfers: [
          _transfer(remaining: 30, harvestDate: '2026-12-01'),
          _transfer(id: '11', active: 0),
        ],
        sowings: [_sowing()],
        inventaris: [_inventory()],
      );

      expect(item.id, '1');
      expect(item.kode, 'A2');
      expect(item.jumlahLubang, 240);
      expect(item.terisi, 40);
      expect(item.kosong, 200);
      expect(item.status, V2MejaStatus.tersedia);
      expect(item.tanaman, hasLength(1));
      expect(item.tanaman.single.varietas, 'Romaine');
      expect(item.tanaman.single.jumlahAktif, 40);
      expect(item.tanaman.single.jumlahAwal, 40);
    });

    test('tanpa batch tetap tampil dengan nama tanaman umum', () {
      final item = v2MejaItemFromRecord(_table(plants: 0));
      expect(item.tanaman, isEmpty);
      expect(item.terisi, 0);
    });

    test('membawa laporan kerusakan nyata ke daftar rusak', () {
      final item = v2MejaItemFromRecord(
        _table(),
        transfers: [_transfer()],
        sowings: [_sowing()],
        inventaris: [_inventory()],
        damages: const [
          DamageRecord(
            id: '4',
            transferId: '10',
            date: '2026-11-12',
            plantCount: 12,
            category: 'Busuk akar',
            note: 'Daun menguning',
          ),
        ],
      );

      expect(item.tanaman.single.transferId, '10');
      final rusak = item.rusak.single;
      expect(rusak.id, '4');
      expect(rusak.transferId, '10');
      expect(rusak.jenis, 'Busuk akar');
      expect(rusak.jumlah, 12);
      expect(rusak.varietas, 'Romaine');
      expect(rusak.meja, 'A2');
      expect(rusak.keterangan, 'Daun menguning');
    });
  });

  group('v2PanenItemFromRecord', () {
    HarvestRecord record({String? note, bool includeTotals = true}) {
      final total = includeTotals ? _kg('2.50') : null;
      final reject = includeTotals ? _kg('0.20') : null;
      return HarvestRecord(
        id: '9',
        userId: '1',
        date: '2026-11-12',
        note: note,
        details: [
          HarvestDetail(
            id: '5',
            transferId: '10',
            tableId: '1',
            tableCode: 'A2',
            sowingDate: '2026-10-17',
            transferDate: '2026-11-01',
            plantCount: 40,
            saleable: _kg('2.30'),
            total: total,
            reject: reject,
          ),
        ],
        saleable: _kg('2.30'),
        total: total,
        reject: reject,
      );
    }

    test('membawa berat kg, meja, dan varietas dari batch', () {
      final item = v2PanenItemFromRecord(
        record(note: 'Pagi'),
        transfers: [_transfer()],
        tables: [_table()],
        sowings: [_sowing()],
        inventaris: [_inventory()],
      );

      expect(item.id, '9');
      expect(item.meja, 'Meja A2');
      expect(item.varietas, 'Romaine');
      expect(item.jumlahTanaman, 40);
      expect(item.beratTotal, 2.5);
      expect(item.beratReject, 0.2);
      expect(item.beratLayak, 2.3);
      expect(item.keterangan, 'Pagi');
    });

    test('tanpa total memakai berat layak dan reject nol', () {
      final item = v2PanenItemFromRecord(record(includeTotals: false));
      expect(item.beratTotal, 2.3);
      expect(item.beratReject, 0);
    });

    test('rincian per detail dipakai koreksi multi-rincian', () {
      final multi = HarvestRecord(
        id: '9',
        userId: '1',
        date: '2026-11-12',
        details: [
          HarvestDetail(
            id: '5',
            transferId: '10',
            tableId: '1',
            tableCode: 'A2',
            sowingDate: '2026-10-17',
            transferDate: '2026-11-01',
            plantCount: 40,
            saleable: _kg('2.30'),
            total: _kg('2.50'),
            reject: _kg('0.20'),
          ),
          HarvestDetail(
            id: '6',
            transferId: '11',
            tableId: '2',
            tableCode: 'B1',
            sowingDate: '2026-10-18',
            transferDate: '2026-11-02',
            plantCount: 30,
            saleable: _kg('1.00'),
            total: _kg('1.10'),
            reject: _kg('0.10'),
          ),
        ],
        saleable: _kg('3.30'),
        total: _kg('3.60'),
        reject: _kg('0.30'),
      );

      final item = v2PanenItemFromRecord(
        multi,
        tables: [_table(), _table(id: '2', code: 'B1')],
      );

      expect(item.rincian, hasLength(2));
      expect(item.rincian[0].detailId, '5');
      expect(item.rincian[0].label, 'Meja A2');
      expect(item.rincian[0].beratTotal, 2.5);
      expect(item.rincian[0].beratReject, 0.2);
      expect(item.rincian[1].detailId, '6');
      expect(item.rincian[1].label, 'Meja B1');
      expect(item.rincian[1].beratTotal, 1.1);
      expect(item.rincian[1].beratReject, 0.1);
    });
  });

  group('v2PanenEstimasiFromTransfer', () {
    test('sisa hari dari backend dipakai apa adanya', () {
      final estimasi = v2PanenEstimasiFromTransfer(
        _transfer(remaining: 19),
        table: _table(),
        sowings: [_sowing()],
        inventaris: [_inventory()],
      );
      expect(estimasi.meja, 'Meja A2');
      expect(estimasi.varietas, 'Romaine');
      expect(estimasi.jumlahTanaman, 40);
      expect(estimasi.hariLagi, 19);
      expect(estimasi.transferId, '10');
    });

    test('sisa negatif dijepit ke nol (siap panen)', () {
      final estimasi = v2PanenEstimasiFromTransfer(
        _transfer(remaining: -3, harvestDate: '2026-11-10'),
      );
      expect(estimasi.hariLagi, 0);
      expect(estimasi.siapPanen, isTrue);
    });
  });

  group('v2RawatItemFromDamage', () {
    test('memakai jenis kerusakan, jumlah, dan catatan apa adanya', () {
      final item = v2RawatItemFromDamage(
        const DamageRecord(
          id: '4',
          transferId: '10',
          date: '2026-11-12',
          plantCount: 12,
          category: 'Busuk akar',
          note: 'Daun menguning',
        ),
        _table(),
      );

      expect(item.id, '4');
      expect(item.hama, 'Busuk akar');
      expect(item.meja, 'Meja A2');
      expect(item.meta, '12 tanaman');
      expect(item.extra, 'Daun menguning');
      expect(item.foto, isFalse);
    });

    test('tanpa catatan memakai kalimat laporan umum', () {
      final item = v2RawatItemFromDamage(
        const DamageRecord(
          id: '5',
          transferId: '10',
          date: '2026-11-13',
          plantCount: 3,
          category: 'Thrips',
        ),
        _table(),
      );
      expect(item.extra, 'Laporan kerusakan tanaman.');
    });
  });
}
