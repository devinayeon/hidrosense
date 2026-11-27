import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_meja_form_page.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_text_field.dart';

void main() {
  testWidgets('jumlah lubang di atas 250 ditolak dengan pesan di field', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: V2MejaFormPage.create()));

    await tester.enterText(find.byType(TextField).at(1), '251');
    await tester.enterText(find.byType(TextField).at(2), 'tset');
    await tester.tap(find.text('Simpan'));
    await tester.pump();

    expect(find.text('Maksimal 250 lubang'), findsOneWidget);
    expect(find.text('Tambah meja'), findsOneWidget);
  });

  testWidgets('kode meja dibuat otomatis dan tidak bisa diketik', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: V2MejaFormPage(takenCodes: {'A2'})),
    );

    // Kode lanjutan dari daftar meja yang ada, bukan hasil ketikan pemakai.
    final kode = tester.widget<V2TextField>(find.byType(V2TextField).first);
    expect(kode.enabled, isFalse);
    expect(kode.controller!.text, 'A3');
    expect(find.text('Kode dibuat otomatis'), findsOneWidget);
  });

  testWidgets('keterangan lebih dari 1.000 karakter ditolak', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: V2MejaFormPage.create()));

    await tester.enterText(find.byType(TextField).at(1), '240');
    await tester.enterText(find.byType(TextField).at(2), 'k' * 1001);
    await tester.tap(find.text('Simpan'));
    await tester.pump();

    expect(find.text('Maksimal 1.000 karakter'), findsOneWidget);
  });

  testWidgets('pesan galat hilang begitu isian diperbaiki (K-15)', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: V2MejaFormPage.create()));

    await tester.enterText(find.byType(TextField).at(1), '0');
    await tester.tap(find.text('Simpan'));
    await tester.pump();
    expect(find.text('Isi angka lebih dari 0'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), '240');
    await tester.pump();
    expect(find.text('Isi angka lebih dari 0'), findsNothing);
  });
}
