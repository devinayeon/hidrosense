import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_beranda_page.dart';

void main() {
  testWidgets('kartu stok menipis membuka daftar semua barang menipis/habis', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: V2BerandaPage()));

    final kartu = find.text('Stok menipis');
    await tester.ensureVisible(kartu);
    await tester.tap(kartu);
    await tester.pumpAndSettle();

    // Cakupan kartu = semua jenis barang di bawah minimum, bukan hanya benih.
    // Benih Butterhead menipis dan media Rockwool habis sama-sama tampil.
    expect(find.text('Benih Butterhead'), findsOneWidget);
    expect(find.text('Rockwool'), findsOneWidget);

    // Barang yang masih aman tetap tersaring keluar.
    expect(find.text('Benih Romaine'), findsNothing);
    expect(find.text('Nutrisi AB Mix'), findsNothing);
  });
}
