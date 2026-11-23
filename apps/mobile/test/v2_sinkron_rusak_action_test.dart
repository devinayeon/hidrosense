// Regresi: pada 11.7, hanya baris yang benar-benar bentrok versi yang boleh
// membuka dialog konflik 11.8. Baris "Rusak" yang ditolak server (bukan bentrok
// versi) sebelumnya selalu membuka dialog itu, padahal tidak ada yang bisa
// diselesaikan dari HP.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_sinkron_data.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_sinkron_page.dart';

Future<void> _pump(WidgetTester tester, List<V2SinkronItem> items) async {
  await tester.pumpWidget(
    MaterialApp(
      home: V2SinkronPage(state: V2SinkronState.partial, items: items),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('baris Rusak gagal yang bukan konflik tidak membuka dialog', (
    tester,
  ) async {
    await _pump(tester, const [
      V2SinkronItem(
        jenis: V2SinkronJenis.rusak,
        subtitle: 'Jumlah melebihi tanaman aktif',
        kode: '10.05',
        status: V2SinkronStatus.gagal,
      ),
    ]);

    await tester.tap(find.text('Rusak'));
    await tester.pumpAndSettle();

    expect(find.text('Data berubah di server'), findsNothing);
  });

  testWidgets('baris konflik sejati tetap membuka dialog 11.8', (tester) async {
    await _pump(tester, const [
      V2SinkronItem(
        jenis: V2SinkronJenis.rusak,
        subtitle: 'Berubah di server',
        kode: '10.05',
        status: V2SinkronStatus.gagal,
        nama: 'Meja A2',
        konflik: true,
      ),
    ]);

    await tester.tap(find.text('Rusak'));
    await tester.pumpAndSettle();

    expect(find.text('Data berubah di server'), findsOneWidget);
  });
}
