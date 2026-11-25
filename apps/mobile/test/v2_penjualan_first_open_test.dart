import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/viewmodels/penjualan_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/v2_penjualan_store.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_penjualan_store.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_penjualan_list_page.dart';
import 'package:http/http.dart' as http;

import 'support/harvest_fixture.dart';
import 'support/sales_fixture.dart';

// Laporan pemilik (2026-11-23): internet ada, tetapi pertama kali membuka
// Penjualan muncul "Gagal memuat"; setelah "Coba lagi" langsung berhasil.
({V2PenjualanApiStore store, FakeSalesRepository sales}) _setup({
  required int failFirst,
  bool autoLoad = true,
}) {
  final api = salesApi((_) async => http.Response('{}', 500));
  final sales = FakeSalesRepository(api)..records = [saleRecord()];
  var calls = 0;
  sales.onList = () async {
    calls++;
    if (calls <= failFirst) {
      throw http.ClientException('Connection closed before full header');
    }
    return List.unmodifiable(sales.records);
  };
  final harvests = FakeHarvestRepository(api)..records = [saleHarvest()];
  final viewModel = PenjualanViewModel(sales, harvests, autoLoad: autoLoad);
  addTearDown(viewModel.dispose);
  addTearDown(api.close);
  return (
    store: V2PenjualanApiStore(viewModel, loadRetryDelay: Duration.zero),
    sales: sales,
  );
}

void main() {
  test(
    'pemuatan pertama yang gagal sesaat berhasil tanpa menekan Coba lagi',
    () async {
      final setup = _setup(failFirst: 1, autoLoad: false);
      final snapshot = await setup.store.load();
      expect(snapshot.items, hasLength(1));
      expect(snapshot.items.single.pembeli, 'Supermarket Jaya');
    },
  );

  test(
    'pemuatan di latar bertabrakan dengan pemuatan halaman: tetap berhasil',
    () async {
      final setup = _setup(failFirst: 1);
      final snapshot = await setup.store.load();
      expect(snapshot.items, hasLength(1));
    },
  );

  test('galat yang menetap tetap dilaporkan setelah satu ulangan', () async {
    final setup = _setup(failFirst: 99, autoLoad: false);
    await expectLater(
      setup.store.load(),
      throwsA(isA<V2PenjualanStoreException>()),
    );
    expect(setup.sales.listReads, 2);
  });

  testWidgets(
    'halaman Penjualan tidak menampilkan "Gagal memuat" pada kegagalan sesaat',
    (tester) async {
      final setup = _setup(failFirst: 1, autoLoad: false);
      await tester.pumpWidget(
        MaterialApp(home: V2PenjualanListPage(store: setup.store)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gagal memuat'), findsNothing);
      expect(find.text('Coba lagi'), findsNothing);
      expect(find.text('Supermarket Jaya'), findsOneWidget);
      expect(find.text('Catat penjualan'), findsOneWidget);
    },
  );
}
