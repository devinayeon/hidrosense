import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_meja_form_page.dart';

void main() {
  testWidgets('jumlah lubang di atas 250 ditolak dengan pesan di field', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: V2MejaFormPage.create()));

    await tester.enterText(find.byType(TextField).at(0), 'test');
    await tester.enterText(find.byType(TextField).at(1), '251');
    await tester.enterText(find.byType(TextField).at(2), 'tset');
    await tester.tap(find.text('Simpan'));
    await tester.pump();

    expect(find.text('Maksimal 250 lubang'), findsOneWidget);
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

  testWidgets('pesan galat hilang begitu isian diperbaiki (K-15)', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: V2MejaFormPage.create()));

    await tester.enterText(find.byType(TextField).at(0), 'A2');
    await tester.enterText(find.byType(TextField).at(1), '0');
    await tester.tap(find.text('Simpan'));
    await tester.pump();
    expect(find.text('Isi angka lebih dari 0'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), '240');
    await tester.pump();
    expect(find.text('Isi angka lebih dari 0'), findsNothing);
  });

  testWidgets('kode meja yang sudah dipakai ditolak tanpa menutup form (K-14)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: V2MejaFormPage(takenCodes: {'A2'})),
    );

    await tester.enterText(find.byType(TextField).at(0), 'a2');
    await tester.enterText(find.byType(TextField).at(1), '240');
    await tester.enterText(find.byType(TextField).at(2), 'dekat pintu');
    await tester.tap(find.text('Simpan'));
    await tester.pump();

    expect(find.text('Kode meja sudah dipakai'), findsOneWidget);
    // Form tetap terbuka dan isian lain tidak hilang.
    expect(find.text('Tambah meja'), findsOneWidget);
    expect(find.text('240'), findsOneWidget);
    expect(find.text('dekat pintu'), findsOneWidget);
  });
}
