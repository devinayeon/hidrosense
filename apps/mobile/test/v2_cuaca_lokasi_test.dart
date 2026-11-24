// Regresi BUG-17: kartu cuaca menampilkan lokasi cadangan Malang/Batu/Pasuruan
// padahal lokasi mitra ada di Ambulu, Jember. Daftar cadangan harus memakai
// Ambulu sebagai pilihan awal.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_cuaca_page.dart';

void main() {
  testWidgets('lokasi cadangan memakai Ambulu, bukan Malang', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: V2CuacaPage()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Ambulu'), findsWidgets);
    expect(find.textContaining('Malang'), findsNothing);
  });
}
