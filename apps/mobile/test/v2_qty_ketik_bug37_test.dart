// Regresi BUG-37: hanya "Pindah ke meja" yang bisa mengetik jumlah; form
// semaian, catat stok, catat panen, catat rusak, dan konfirmasi rawat masih
// harus menekan minus/plus satu per satu untuk jumlah besar.
//
// Uji ini memastikan setiap pemakai V2QtyField (komponen angka bersama) bisa
// diketuk lalu diketik. Di kode lama `onChanged` belum dipasang di kelima
// halaman itu, jadi dialog "Jumlah" tidak pernah muncul.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_inventaris_catat_sheet.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_inventaris_data.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_panen_form_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_rawat_konfirmasi_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_semaian_form_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_tanaman_rusak_page.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_stepper.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(360, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pumpAndSettle();
}

int _nilai(WidgetTester tester) =>
    tester.widget<V2QtyField>(find.byType(V2QtyField)).value;

/// Ketuk angka, ketik [baru] di dialog, simpan, lalu pastikan nilainya berubah.
Future<void> _ketik(WidgetTester tester, int baru) async {
  final qty = find.byType(V2QtyField);
  await tester.ensureVisible(qty);
  await tester.pumpAndSettle();
  final awal = _nilai(tester);
  await tester.tap(find.descendant(of: qty, matching: find.text('$awal')));
  await tester.pumpAndSettle();
  expect(
    find.text('Jumlah'),
    findsOneWidget,
    reason: 'angka tidak bisa diketuk untuk diketik',
  );
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
  expect(_nilai(tester), baru);
}

void main() {
  testWidgets('form semaian: jumlah bahan bisa diketik', (tester) async {
    await _pump(tester, const V2SemaianFormPage.create());
    await _ketik(tester, 5);
  });

  testWidgets('catat stok: jumlah pakai bisa diketik', (tester) async {
    await _pump(
      tester,
      const Scaffold(body: V2CatatStokSheet(item: designDetailBiasa)),
    );
    await _ketik(tester, 3);
  });

  testWidgets('catat panen: jumlah tanaman bisa diketik', (tester) async {
    await _pump(tester, const V2PanenFormPage.catat());
    await _ketik(tester, 120);
  });

  testWidgets('catat rusak: jumlah tanaman bisa diketik', (tester) async {
    await _pump(tester, V2CatatRusakPage.catat());
    await _ketik(tester, 5);
  });

  testWidgets('konfirmasi rawat: jumlah botol bisa diketik', (tester) async {
    await _pump(tester, const V2RawatKonfirmasiPage.biasa());
    await _ketik(tester, 2);
  });

  testWidgets('komponen angka bersama aman pada skala teks 2.0', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, w) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: w!,
        ),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: V2QtyField(
              value: 1234,
              unit: 'tanaman',
              onChanged: (_) {},
              onMinus: () {},
              onPlus: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1234'), findsOneWidget);
    expect(find.text('tanaman'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}