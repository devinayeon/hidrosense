// Regresi sesi 10 lanjutan 2: kode meja dibuat otomatis dan tidak bisa diketik,
// placeholder jumlah lubang menulis "maksimal 250", dan tombol "Tambah
// tanaman" hilang saat meja berstatus Perawatan.
//
// Di kode lama: field "Kode meja" bisa diketik (form tambah menebak kode, form
// ubah menampilkan kode yang masih bisa diubah), placeholder menulis "maksimal
// 1.000", dan footer Perawatan menampilkan tombol "Tambah tanaman" yang mati.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_meja_data.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_meja_detail_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_meja_form_page.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_text_field.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(420, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pumpAndSettle();
}

/// Field "Kode meja" adalah V2TextField pertama di form.
V2TextField _kodeField(WidgetTester tester) =>
    tester.widget<V2TextField>(find.byType(V2TextField).first);

void main() {
  group('tambah meja', () {
    testWidgets('kode dibuat otomatis dan tidak bisa diketik', (tester) async {
      await _pump(tester, const V2MejaFormPage(takenCodes: {'A2'}));

      final kode = _kodeField(tester);
      expect(kode.enabled, isFalse, reason: 'kode tidak boleh diisi manual');
      expect(kode.controller!.text, 'A3', reason: 'lanjutan dari A2');
      expect(find.text('Kode dibuat otomatis'), findsOneWidget);
    });

    testWidgets('kode memakai A1 saat belum ada meja', (tester) async {
      await _pump(tester, const V2MejaFormPage.create());

      expect(_kodeField(tester).controller!.text, 'A1');
    });

    testWidgets('placeholder jumlah lubang menulis maksimal 250', (
      tester,
    ) async {
      await _pump(tester, const V2MejaFormPage.create());

      expect(find.text('Contoh: 240 (maksimal 250)'), findsOneWidget);
      expect(find.text('Contoh: 240 (maksimal 1.000)'), findsNothing);
    });
  });

  group('ubah meja', () {
    testWidgets('kode yang ada ditampilkan dan tidak bisa diketik', (
      tester,
    ) async {
      await _pump(tester, V2MejaFormPage(meja: designMejaA2));

      final kode = _kodeField(tester);
      expect(kode.enabled, isFalse);
      expect(kode.controller!.text, 'A2');
    });
  });

  group('detail meja', () {
    testWidgets('status Perawatan menghilangkan tombol Tambah tanaman', (
      tester,
    ) async {
      await _pump(tester, V2MejaDetailPage(item: designMejaA2Perawatan));

      expect(find.text('Tambah tanaman'), findsNothing);
      expect(
        find.text('Meja Perawatan tidak menerima tanaman baru.'),
        findsOneWidget,
      );
    });

    testWidgets('status Tersedia tetap menampilkan tombol Tambah tanaman', (
      tester,
    ) async {
      await _pump(tester, V2MejaDetailPage(item: designMejaA2));

      expect(find.text('Tambah tanaman'), findsOneWidget);
    });
  });
}
