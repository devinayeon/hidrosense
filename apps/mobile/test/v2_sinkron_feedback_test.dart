// Regresi BUG-21: "Sinkron sekarang" menampilkan sukses walau tidak ada satu
// pun baris yang benar-benar terkirim (mis. perangkat tanpa internet, atau
// antrean kosong). Umpan balik harus jujur: sukses hanya bila ada pengiriman
// nyata, gagal jelas bila jaringan putus, dan tidak ada data bila antrean kosong.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/viewmodels/v2_sync_replayer.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_sinkron_page.dart';

Future<void> _pumpAndSync(WidgetTester tester, V2SyncRun result) async {
  await tester.pumpWidget(
    MaterialApp(
      home: V2SinkronPage(
        state: V2SinkronState.ready,
        onSyncNow: (_) async => result,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Sinkron sekarang'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('antrean kosong tidak mengaku "Sinkron selesai"', (tester) async {
    await _pumpAndSync(tester, const V2SyncRun());

    expect(find.text('Sinkron selesai'), findsNothing);
    expect(find.text('Tidak ada data untuk disinkronkan.'), findsOneWidget);
  });

  testWidgets('jaringan putus menampilkan gagal, bukan sukses', (tester) async {
    await _pumpAndSync(
      tester,
      const V2SyncRun(total: 2, pending: 2),
    );

    expect(find.text('Sinkron selesai'), findsNothing);
    expect(
      find.textContaining('Tidak ada koneksi internet'),
      findsWidgets,
    );
  });

  testWidgets('sukses hanya saat baris benar-benar terkirim', (tester) async {
    await _pumpAndSync(tester, const V2SyncRun(total: 2, sent: 2));

    expect(find.text('Sinkron selesai'), findsOneWidget);
    expect(find.textContaining('Tidak ada koneksi internet'), findsNothing);
  });
}
