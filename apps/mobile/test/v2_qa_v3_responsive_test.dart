import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_akun_tab_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_beranda_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_inventaris_list_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_meja_detail_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_panen_form_page.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_rawat_list_page.dart';
import 'package:hidrosense_mobile/views/v2/theme/v2_tokens.dart';

/// Frame `QA v3` di Figma: enam layar pada 390x844 (teks 130%) dan 360x640.
/// Tes ini memastikan tidak ada overflow pada ukuran dan skala teks itu.
void main() {
  final screens = <String, Widget Function()>{
    '2.1 Beranda (Petani)': () => const V2BerandaPage(),
    '3.1 Lainnya (Petani)': () => const Scaffold(
      body: V2AkunTabView(role: V2BerandaRole.petani),
    ),
    '4.1 Stok (Petani)': () => const V2InventarisListPage.ready(),
    '6.11 Detail meja': () => V2MejaDetailPage.biasa(),
    '7.8 Catat panen': () => const V2PanenFormPage.catat(),
    '9.1 Rawat (Petani)': () => const V2RawatListPage.petani(),
  };
  const sizes = <String, Size>{
    'TEXT130 390x844': Size(390, 844),
    'W360 360x640': Size(360, 640),
  };

  for (final screen in screens.entries) {
    for (final size in sizes.entries) {
      testWidgets('${screen.key} tanpa overflow pada ${size.key}', (
        tester,
      ) async {
        tester.view.physicalSize = size.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: V2Theme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: screen.value(),
          ),
        );
        // Skeleton dan animasi memicu frame tanpa henti: maju per langkah,
        // bukan pumpAndSettle.
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
