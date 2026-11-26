// Regresi: sheet "Ubah status meja" dulu langsung menutup dan memunculkan
// pop-up konfirmasi begitu salah satu opsi diketuk. Yang benar: opsi hanya
// dipilih dulu di dalam sheet, dan konfirmasi baru muncul setelah "Simpan".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_meja_data.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_meja_detail_page.dart';

void main() {
  testWidgets(
    'opsi status hanya dipilih; konfirmasi muncul setelah "Simpan"',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      V2MejaStatus? disimpan;
      await tester.pumpWidget(
        MaterialApp(
          home: V2MejaDetailPage(
            item: designMejaA2,
            onUbahStatus: (status) async => disimpan = status,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ubah status'));
      await tester.pumpAndSettle();
      expect(find.text('Ubah status meja'), findsOneWidget);

      // Mengetuk opsi hanya memilih, sheet tetap terbuka, belum ada konfirmasi.
      await tester.tap(find.text('Perawatan'));
      await tester.pumpAndSettle();
      expect(
        find.text('Ubah status meja?'),
        findsNothing,
        reason: 'konfirmasi tidak boleh muncul saat opsi status diketuk',
      );
      expect(
        find.text('Ubah status meja'),
        findsOneWidget,
        reason: 'sheet harus tetap terbuka setelah memilih status',
      );

      // "Simpan" menutup sheet, lalu pop-up konfirmasi tampil.
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(
        find.text('Ubah status meja?'),
        findsOneWidget,
        reason: 'konfirmasi harus muncul setelah "Simpan"',
      );
      expect(find.textContaining('Perawatan'), findsWidgets);

      // Konfirmasi menyimpan status yang tadi dipilih.
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(disimpan, V2MejaStatus.perawatan);
    },
  );
}