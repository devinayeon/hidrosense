import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_meja_form_page.dart';

void main() {
  testWidgets('jumlah lubang di atas 1.000 ditolak dengan pesan di field', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: V2MejaFormPage.create()));

    await tester.enterText(find.byType(TextField).at(0), 'test');
    await tester.enterText(find.byType(TextField).at(1), '1231');
    await tester.enterText(find.byType(TextField).at(2), 'tset');
    await tester.tap(find.text('Simpan'));
    await tester.pump();

    expect(find.text('Maksimal 1.000 lubang'), findsOneWidget);
    expect(find.text('Tambah meja'), findsOneWidget);
  });

  testWidgets('kode meja lebih dari 30 karakter ditolak', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: V2MejaFormPage.create()));

    await tester.enterText(find.byType(TextField).at(0), 'M' * 31);
    await tester.enterText(find.byType(TextField).at(1), '240');
    await tester.tap(find.text('Simpan'));
    await tester.pump();

    expect(find.text('Maksimal 30 karakter'), findsOneWidget);
  });

  testWidgets('keterangan lebih dari 1.000 karakter ditolak', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: V2MejaFormPage.create()));

    await tester.enterText(find.byType(TextField).at(0), 'A2');
    await tester.enterText(find.byType(TextField).at(1), '240');
    await tester.enterText(find.byType(TextField).at(2), 'k' * 1001);
    await tester.tap(find.text('Simpan'));
    await tester.pump();

    expect(find.text('Maksimal 1.000 karakter'), findsOneWidget);
  });
}
