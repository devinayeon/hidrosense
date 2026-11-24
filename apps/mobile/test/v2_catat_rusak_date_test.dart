// Regresi BUG-27: form "Catat rusak" memaku tanggal contoh 15 Nov 2026 sebagai
// nilai awal, padahal default harus hari ini (WIB). Uji ini memakai jam yang
// bisa disuntik, termasuk batas tengah malam WIB, dan menjaga tanggal contoh
// galeri tetap 15 Nov.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_meja_data.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_penjualan_form_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_tanaman_rusak_page.dart';

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(480, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: home));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('"Catat rusak" memakai hari ini WIB, bukan 15 Nov', (tester) async {
    await _pump(
      tester,
      V2CatatRusakPage(
        meja: designMejaA2,
        // 23 Nov 23.45 WIB.
        clock: () => DateTime.utc(2026, 11, 23, 16, 45),
      ),
    );

    expect(find.text('23 Nov 2026'), findsOneWidget);
    expect(find.text('15 Nov 2026'), findsNothing);
  });

  testWidgets('"Catat rusak" berpindah hari tepat setelah tengah malam WIB', (
    tester,
  ) async {
    await _pump(
      tester,
      V2CatatRusakPage(
        meja: designMejaA2,
        // 24 Nov 00.05 WIB.
        clock: () => DateTime.utc(2026, 11, 23, 17, 5),
      ),
    );

    expect(find.text('24 Nov 2026'), findsOneWidget);
  });

  testWidgets('"Ubah kerusakan" memakai tanggal catatan, bukan hari ini', (
    tester,
  ) async {
    await _pump(tester, V2CatatRusakPage.ubah());

    expect(find.text('10 Nov 2026'), findsOneWidget);
  });

  testWidgets('galeri "Catat rusak" tetap menampilkan 15 Nov', (tester) async {
    await _pump(tester, V2CatatRusakPage.catat());

    expect(find.text('15 Nov 2026'), findsOneWidget);
  });

  testWidgets('penjualan baru memakai tanggal yang dikirim alur nyata', (
    tester,
  ) async {
    await _pump(
      tester,
      V2PenjualanFormPage(initialDate: DateTime(2026, 11, 24)),
    );

    expect(find.text('24 Nov 2026'), findsOneWidget);
    expect(find.text('15 Nov 2026'), findsNothing);
  });

  testWidgets('galeri penjualan baru tetap memakai 15 Nov', (tester) async {
    await _pump(tester, const V2PenjualanFormPage.create());

    expect(find.text('15 Nov 2026'), findsOneWidget);
  });
}
