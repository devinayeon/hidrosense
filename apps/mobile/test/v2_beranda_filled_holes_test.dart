// Regresi BUG-18: kartu "Lubang terisi" di Beranda dulu tidak bisa ditekan.
// Sekarang kartu harus membuka tab Tanam langsung pada segmen Meja.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_beranda_page.dart';

void main() {
  testWidgets('kartu "Lubang terisi" membuka Tanam → Meja', (tester) async {
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

    // Belum berpindah tab: isi Tanam belum dibangun.
    expect(segmen, isEmpty);

    await tester.ensureVisible(find.text('Lubang terisi'));
    await tester.tap(find.text('Lubang terisi'));
    await tester.pumpAndSettle();

    expect(segmen.last, 1);
    expect(find.text('segmen:1'), findsOneWidget);
  });
}
