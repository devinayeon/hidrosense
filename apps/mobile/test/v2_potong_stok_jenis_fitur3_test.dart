// Fitur-3 (D-29): potong stok dari rekomendasi hanya untuk jenis NUTRISI dan
// OBAT; benih/media/jenis lain tidak ditawarkan, dan bila tidak ada stok yang
// bisa dipotong lembar terima menjelaskannya.
//
// Bukti gagal di kode lama: `bolehPotongStok`/`stockOptionsDari` belum ada dan
// filter lama hanya `r.active`, jadi benih ikut masuk; lembar terima tanpa stok
// juga tidak menampilkan pesan apa pun.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/inventory_record.dart';
import 'package:hidrosense_mobile/features/pest/data/pest_models.dart';
import 'package:hidrosense_mobile/features/pest/presentation/widgets/decision_sheets.dart';

import 'pest_repository_test.dart' show recJson;

InventoryRecord _inv(String id, String jenis, {int aktif = 1}) =>
    InventoryRecord.fromJson({
      'id_inventaris': id,
      'public_id': null,
      'version': null,
      'id_jenis_inventaris': '2',
      'id_obat': null,
      'nama_barang': 'Barang $id',
      'satuan': 'ml',
      'stok_minimum': null,
      'status_aktif': aktif,
      'nama_jenis': jenis,
      'nama_obat': null,
      'saldo': '10',
    });

void main() {
  test('hanya jenis nutrisi dan obat yang bisa dipotong (D-29)', () {
    expect(bolehPotongStok('Nutrisi'), isTrue);
    expect(bolehPotongStok('obat'), isTrue);
    expect(bolehPotongStok('Benih'), isFalse);
    expect(bolehPotongStok('Media'), isFalse);
    expect(bolehPotongStok('Alat'), isFalse);
  });

  test('daftar stok menyaring jenis non-perawatan (D-29)', () {
    final opsi = stockOptionsDari(<InventoryRecord>[
      _inv('1', 'Nutrisi'),
      _inv('2', 'Benih'),
      _inv('3', 'Obat'),
      _inv('4', 'Media'),
      _inv('5', 'Nutrisi', aktif: 0),
    ]);
    expect(opsi.map((o) => o.id).toList(), ['1', '3']);
  });

  testWidgets('lembar terima menjelaskan bila stok tidak bisa dipotong', (
    tester,
  ) async {
    final recommendation = PestRecommendation.fromJson(recJson());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAcceptSheet(
                context,
                recommendation,
                stock: const <StockOption>[],
              ),
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    expect(
      find.text('Belum ada stok nutrisi atau obat yang bisa dipotong.'),
      findsOneWidget,
    );
    expect(find.text('Potong dari stok (opsional)'), findsNothing);
  });
}