// Tes teks status stok pada label yang dipakai layar inventaris.
// Matriks ini dipindahkan dari tes layar inventaris lama yang sudah dihapus,
// supaya aturan habis, menipis, mencukupi, dan tersedia tetap terjaga.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/inventory_record.dart';
import 'package:hidrosense_mobile/views/theme/app_theme.dart';
import 'package:hidrosense_mobile/views/widgets/inventory_stock_label.dart';

InventoryRecord _inventory({required String balance, String? minimum}) =>
    InventoryRecord.fromJson({
      'id_inventaris': '1',
      'public_id': null,
      'version': null,
      'id_jenis_inventaris': '1',
      'id_obat': null,
      'nama_barang': 'Pupuk Uji',
      'satuan': 'kg',
      'stok_minimum': minimum,
      'status_aktif': 1,
      'nama_jenis': 'Pupuk',
      'nama_obat': null,
      'saldo': balance,
    });

void main() {
  for (final stockCase in [
    (balance: '0.00', minimum: '1', label: 'Stok habis'),
    (balance: '0', minimum: null, label: 'Stok habis'),
    (balance: '0.25', minimum: '1', label: 'Stok menipis'),
    (balance: '1', minimum: '1', label: 'Stok mencukupi'),
    (balance: '1.01', minimum: '1', label: 'Stok mencukupi'),
    (balance: '0.25', minimum: null, label: 'Stok tersedia'),
  ]) {
    testWidgets(
      'saldo ${stockCase.balance}, minimum ${stockCase.minimum}: '
      '${stockCase.label}',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: InventoryStockLabel(
                item: _inventory(
                  balance: stockCase.balance,
                  minimum: stockCase.minimum,
                ),
              ),
            ),
          ),
        );

        expect(find.text(stockCase.label), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
