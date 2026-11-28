// Regresi sesi 10 (lanjutan): batas jumlah catat stok dan perbaikan pesan
// form tambah semaian.
//
// Di kode lama: jumlah bawaan sheet 2, mode Masuk tidak punya batas sehingga
// server menolak "Saldo stok melebihi batas." di halaman detail, pesan jumlah
// benih "Isi jumlah benih"/"Jumlah benih harus angka", dan kartu "Stok
// berkurang" disembunyikan saat hasilnya minus.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_inventaris_catat_sheet.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_inventaris_data.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_semaian_form_page.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_stepper.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(360, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pumpAndSettle();
}

int _nilai(WidgetTester tester) =>
    tester.widget<V2QtyField>(find.byType(V2QtyField).first).value;

/// Ketuk angka qty, ketik [baru] di dialog, lalu simpan.
Future<void> _ketik(WidgetTester tester, int baru) async {
  final qty = find.byType(V2QtyField).first;
  await tester.ensureVisible(qty);
  await tester.pumpAndSettle();
  final awal = _nilai(tester);
  await tester.tap(find.descendant(of: qty, matching: find.text('$awal')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    ),
    '$baru',
  );
  await tester.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Simpan'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('catat stok', () {
    testWidgets('jumlah bawaan 1 untuk Pakai dan Masuk', (tester) async {
      await _pump(
        tester,
        const Scaffold(body: V2CatatStokSheet(item: designDetailBiasa)),
      );
      expect(_nilai(tester), 1);

      await tester.tap(find.text('Masuk'));
      await tester.pumpAndSettle();
      expect(_nilai(tester), 1);
    });

    testWidgets('Masuk menolak jumlah di atas 10000 di dalam sheet', (
      tester,
    ) async {
      await _pump(
        tester,
        const Scaffold(
          body: V2CatatStokSheet(item: designDetailBiasa, initialMasuk: true),
        ),
      );

      // Stok 12; batas satu kali catat stok masuk adalah 10000.
      await _ketik(tester, 10001);

      expect(find.text('Maksimal 10000 pak'), findsOneWidget);
      expect(
        tester.widget<V2QtyField>(find.byType(V2QtyField)).onPlus,
        isNull,
        reason: 'tombol plus harus berhenti di batas masuk',
      );

      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(
        find.text('Catat stok'),
        findsOneWidget,
        reason: 'sheet harus tetap terbuka saat jumlah melewati batas',
      );
    });

    testWidgets('Masuk menerima tepat 10000 sekali input', (tester) async {
      await _pump(
        tester,
        const Scaffold(
          body: V2CatatStokSheet(item: designDetailBiasa, initialMasuk: true),
        ),
      );

      await _ketik(tester, 10000);

      expect(find.text('Maksimal 10000 pak'), findsNothing);
      expect(find.text('Masuk 10000 pak. Stok jadi 10012 pak.'), findsOneWidget);
    });

    testWidgets('Pakai tetap menolak jumlah melebihi stok di dalam sheet', (
      tester,
    ) async {
      await _pump(
        tester,
        const Scaffold(body: V2CatatStokSheet(item: designDetailBiasa)),
      );
      await _ketik(tester, 15);

      expect(find.text('Stok hanya 12 pak'), findsOneWidget);
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(find.text('Catat stok'), findsOneWidget);
    });
  });

  group('tambah semaian', () {
    testWidgets('jumlah benih dan jumlah bahan bawaan 1', (tester) async {
      await _pump(tester, const V2SemaianFormPage.create());

      final benih = tester.widget<TextField>(find.byType(TextField));
      expect(benih.controller!.text, '1');
      expect(_nilai(tester), 1);
    });

    testWidgets('jumlah benih kosong memakai pesan angka positif', (
      tester,
    ) async {
      await _pump(tester, const V2SemaianFormPage.create());

      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(find.text('Benih harus angka positif'), findsOneWidget);
    });

    testWidgets('info stok berkurang tampil saat stok masih cukup', (
      tester,
    ) async {
      await _pump(tester, const V2SemaianFormPage.create());

      expect(find.text('Benih Romaine: 12 pak jadi 11 pak'), findsOneWidget);
    });

    testWidgets('hasil minus diganti "Stok tidak mencukupi" di info bawah', (
      tester,
    ) async {
      await _pump(tester, const V2SemaianFormPage.create());
      await _ketik(tester, 15);

      expect(find.text('Benih Romaine: Stok tidak mencukupi'), findsOneWidget);
      expect(find.text('Stok hanya 12 pak'), findsOneWidget);
    });
  });
}
