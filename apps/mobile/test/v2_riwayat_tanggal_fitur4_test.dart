// Regresi Fitur-4 (D-32): filter rentang tanggal WIB di Riwayat rotasi.
//
// Batas dari–sampai inklusif dan memakai tanggal WIB yang sama dengan
// pengelompokan D-28. Bukti gagal di kode lama: `saringRiwayatTanggal` belum ada.
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/features/pest/data/pest_models.dart';
import 'package:hidrosense_mobile/features/pest/domain/pest_history_group.dart';

Map<String, dynamic> _recJson(String id, String tanggal) => {
  'id_rekomendasi': id,
  'id_meja': '1',
  'kode_meja': 'M-01',
  'id_hasil_deteksi': null,
  'hama': 'thrips',
  'tingkat': 'sedang',
  'status': 'menunggu',
  'obat': {
    'id_katalog': '10',
    'bahan_aktif': 'Spinosad',
    'jenis': 'kimia',
    'kode_moa': '5',
    'nama_moa': 'Spinosad',
    'catatan': null,
    'phi_hari': null,
    'phi_sumber': null,
    'sumber': 'https://example.test',
    'terverifikasi': false,
  },
  'rule_id': 'ROT-MOA',
  'alasan': 'Serangan sedang.',
  'alasan_penolakan': null,
  'catatan_penolakan': null,
  'tanggal_aplikasi': null,
  'catatan_perawatan': null,
  'tanggal_rekomendasi': tanggal,
  'tanggal_keputusan': null,
  'bahan_terpakai': <Object>[],
};

void main() {
  final items = [
    PestRecommendation.fromJson(_recJson('1', '2026-11-24T02:00:00.000Z')),
    PestRecommendation.fromJson(_recJson('2', '2026-11-25T02:00:00.000Z')),
    PestRecommendation.fromJson(_recJson('3', '2026-11-25T16:59:00.000Z')),
    PestRecommendation.fromJson(_recJson('4', '2026-11-26T01:00:00.000Z')),
  ];

  test('rentang tanggal WIB inklusif di kedua ujung (D-32)', () {
    final hasil = saringRiwayatTanggal(
      items,
      dari: DateTime(2026, 11, 25),
      sampai: DateTime(2026, 11, 26),
    );
    expect(hasil.map((row) => row.id), ['2', '3', '4']);
  });

  test('batas kosong berarti terbuka (D-32)', () {
    expect(
      saringRiwayatTanggal(items, dari: DateTime(2026, 11, 26)).map(
        (row) => row.id,
      ),
      ['4'],
    );
    expect(
      saringRiwayatTanggal(items, sampai: DateTime(2026, 11, 24)).map(
        (row) => row.id,
      ),
      ['1'],
    );
    expect(saringRiwayatTanggal(items), hasLength(4));
  });
}