// Regresi BUG-29: pada form "Pindah ke meja" jumlah besar hanya bisa dicapai
// dengan menekan plus berulang kali, dan meja penuh bisa terpilih sebagai
// bawaan. Uji ini memastikan: (1) minus/plus bisa ditahan untuk berulang,
// (2) angka bisa diketuk lalu diketik, (3) bawaan memilih meja tersedia
// pertama, bukan meja penuh.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_semaian_data.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_pindah_meja_page.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_option_row.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_stepper.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(360, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pumpAndSettle();
}

int _qty(WidgetTester tester) =>
    tester.widget<V2QtyField>(find.byType(V2QtyField)).value;

void main() {
  testWidgets('menahan tombol plus mengubah jumlah lebih dari satu langkah', (
    tester,
  ) async {
    await _pump(tester, V2PindahMejaFormPage.form());
    expect(_qty(tester), 200);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.add)),
    );
    await tester.pump(const Duration(milliseconds: 1200));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(_qty(tester), greaterThan(201));
  });

  testWidgets('angka jumlah bisa diketuk lalu diketik', (tester) async {
    await _pump(tester, V2PindahMejaFormPage.form());

    await tester.tap(find.text('200'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), '150');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(_qty(tester), 150);
  });

  testWidgets('bawaan memilih meja tersedia pertama, bukan meja penuh', (
    tester,
  ) async {
    await _pump(
      tester,
      V2PindahMejaFormPage(
        item: designSemaianRomaineSiapPindah,
        daftarMeja: const <V2SemaianMeja>[
          V2SemaianMeja(nama: 'Meja Penuh', penuh: true),
          V2SemaianMeja(nama: 'Meja Kosong', lubangKosong: 300),
        ],
      ),
    );

    final rows = tester
        .widgetList<V2OptionRow>(find.byType(V2OptionRow))
        .toList();
    final penuh = rows.firstWhere((row) => row.label.contains('Meja Penuh'));
    final kosong = rows.firstWhere((row) => row.label.contains('Meja Kosong'));

    expect(penuh.state, V2OptionState.disabled);
    expect(kosong.state, V2OptionState.selected);
    // Tanpa galat lubang, kartu "Estimasi panen" tetap tampil.
    expect(find.text('Estimasi panen'), findsOneWidget);
    expect(find.textContaining('Lubang kosong hanya'), findsNothing);
  });
}
