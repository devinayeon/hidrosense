import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_beranda_page.dart';

void main() {
  testWidgets('kartu stok menipis membuka tab Stok tersaring Benih + Menipis', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: V2BerandaPage()));

    final kartu = find.text('Stok menipis');
    await tester.ensureVisible(kartu);
    await tester.tap(kartu);
    await tester.pumpAndSettle();

    // Hanya benih berstatus menipis yang tampil; benih aman dan barang jenis
    // lain tersaring keluar, sama seperti tab Stok dengan filter yang sama.
    expect(find.text('Benih Butterhead'), findsOneWidget);
    expect(find.text('Benih Romaine'), findsNothing);
    expect(find.text('Rockwool'), findsNothing);
  });
}
