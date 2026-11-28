// Regresi sesi 13: kartu "Riwayat" di detail barang dipaginasi 3 entri per
// halaman supaya riwayat panjang tidak memanjangkan kartu.
//
// Di kode lama riwayat dipotong tetap di 3 entri (`riwayatTampil`), jadi entri
// ke-4 dan seterusnya tidak pernah bisa dilihat pengguna.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_inventaris_data.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_inventaris_detail_page.dart';

V2InventarisItem _item(int jumlahRiwayat) => V2InventarisItem(
  id: 'stok-uji',
  nama: 'Benih Uji',
  jenis: V2JenisBarang.benih,
  jumlah: 20,
  satuan: 'pak',
  minimum: 3,
  riwayat: <V2InventarisRiwayat>[
    for (var i = 1; i <= jumlahRiwayat; i++)
      V2InventarisRiwayat('Masuk $i pak', 'Hari $i'),
  ],
);

Future<void> _pumpDetail(WidgetTester tester, V2InventarisItem item) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: V2InventarisDetailPage(item: item)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('riwayat 5 entri dipaginasi 3 per halaman', (tester) async {
    await _pumpDetail(tester, _item(5));

    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('Masuk 1 pak'), findsOneWidget);
    expect(find.text('Masuk 2 pak'), findsOneWidget);
    expect(find.text('Masuk 3 pak'), findsOneWidget);
    expect(find.text('Masuk 4 pak'), findsNothing);
    expect(find.text('Masuk 5 pak'), findsNothing);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('2/2'), findsOneWidget);
    expect(find.text('Masuk 1 pak'), findsNothing);
    expect(find.text('Masuk 4 pak'), findsOneWidget);
    expect(find.text('Masuk 5 pak'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left).last);
    await tester.pumpAndSettle();

    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('Masuk 1 pak'), findsOneWidget);
    expect(find.text('Masuk 4 pak'), findsNothing);
  });

  testWidgets('riwayat 3 entri tidak menampilkan kontrol halaman', (
    tester,
  ) async {
    await _pumpDetail(tester, _item(3));

    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.text('1/1'), findsNothing);
    expect(find.text('Masuk 3 pak'), findsOneWidget);
  });
}