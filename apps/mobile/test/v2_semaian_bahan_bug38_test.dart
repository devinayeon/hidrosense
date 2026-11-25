// Regresi BUG-38: tombol "Tambah bahan" hanya mengganti bahan terpilih,
// padahal kontrak POST /penyemaian menerima `materials[]` minimal satu dan
// baris unik. Sekarang tombol itu menambah baris bahan baru.
//
// Bukti gagal di kode lama: `V2SemaianBahanPakai`, `SowingMaterialDraft`, dan
// field `bahanList` belum ada (tidak ter-compile); di form lama memilih bahan
// kedua hanya mengganti baris pertama sehingga "Bahan 2" tidak muncul.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/core/business_date.dart';
import 'package:hidrosense_mobile/viewmodels/sowing_draft.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_semaian_data.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_semaian_form_page.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_option_row.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_stepper.dart';

void main() {
  test('SowingDraft meneruskan semua baris materials', () {
    final draft = SowingDraft(
      date: apiDate(jakartaToday()),
      seedCount: 200,
      note: '',
      materials: const <SowingMaterialDraft>[
        SowingMaterialDraft(inventoryId: 'inv-1', amount: '2', unit: 'pak'),
        SowingMaterialDraft(inventoryId: 'inv-2', amount: '1', unit: 'pak'),
      ],
    );
    expect(draft.errors, isEmpty);
    expect(draft.daftarBahan.length, 2);
    expect(draft.daftarBahan.last.inventoryId, 'inv-2');
  });

  testWidgets('"Tambah bahan" menambah baris, hasil simpan membawa semuanya', (
    tester,
  ) async {
    V2SemaianItem? hasil;
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                hasil = await Navigator.of(context).push<V2SemaianItem>(
                  MaterialPageRoute<V2SemaianItem>(
                    builder: (_) => const V2SemaianFormPage.create(),
                  ),
                );
              },
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    expect(find.text('Bahan'), findsOneWidget);
    expect(find.byType(V2QtyField), findsOneWidget);

    // Tambah baris: pilih bahan yang belum dipakai.
    await tester.tap(find.text('Tambah bahan'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih bahan'), findsOneWidget);
    await tester.tap(find.text('Benih Butterhead'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih'));
    await tester.pumpAndSettle();

    expect(find.text('Bahan 2'), findsOneWidget);
    expect(find.byType(V2QtyField), findsNWidgets(2));

    // Bahan yang sudah dipakai tidak ditawarkan lagi (baris unik).
    await tester.tap(find.text('Tambah bahan'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(V2OptionRow, 'Benih Butterhead'),
      findsNothing,
    );
    expect(find.widgetWithText(V2OptionRow, 'Benih Romaine'), findsNothing);
    await tester.tap(find.text('Benih Lollo Rossa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih'));
    await tester.pumpAndSettle();
    expect(find.byType(V2QtyField), findsNWidgets(3));

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    // Hasil form membawa tiga bahan, bukan satu bahan yang diganti-ganti.
    expect(hasil, isNotNull);
    final item = hasil!;
    final bahan = item.bahanList!;
    expect(bahan.length, 3);
    expect(bahan[0].nama, 'Romaine');
    expect(bahan[1].nama, 'Butterhead');
    expect(bahan[2].nama, 'Lollo Rossa');
    // Kolom tunggal tetap diisi bahan pertama untuk pemakai lama.
    expect(item.bahanAmount, '2');
    expect(item.bahanUnit, 'pak');
  });
}