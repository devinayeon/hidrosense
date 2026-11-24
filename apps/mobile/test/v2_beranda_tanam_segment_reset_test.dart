// Regresi BUG-25: setelah kartu "Lubang terisi" membuka Tanam → Meja, mengetuk
// tab Tanam lagi harus kembali ke Semaian. Sebelumnya segmen Meja tersimpan
// terus sehingga tab Tanam selalu terbuka di Meja.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_beranda_page.dart';

void main() {
  testWidgets('tab Tanam kembali ke Semaian setelah kartu "Lubang terisi"', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final segmen = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: V2BerandaPage(
          tanamTabBuilder: (s) {
            segmen.add(s);
            return Center(child: Text('segmen:$s'));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Kartu membuka Tanam → Meja.
    await tester.ensureVisible(find.text('Lubang terisi'));
    await tester.tap(find.text('Lubang terisi'));
    await tester.pumpAndSettle();
    expect(find.text('segmen:1'), findsOneWidget);
    expect(segmen.last, 1);

    // Pindah ke Stok lalu ketuk tab Tanam: harus mulai dari Semaian.
    await tester.tap(find.text('Stok').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tanam').last);
    await tester.pumpAndSettle();

    expect(find.text('segmen:0'), findsOneWidget);
    expect(find.text('segmen:1'), findsNothing);
    expect(segmen.last, 0);
  });
}