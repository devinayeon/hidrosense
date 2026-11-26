// Regresi BUG-42 & BUG-43 di Detail panen.
//
// BUG-42: "Catat penjualan" dari Detail panen membuka form dengan tanggal
// contoh 15 Nov dan tanpa store, jadi "Simpan" hanya menutup form (tidak
// menulis). Perbaikannya: Detail panen tersambung mengirim tanggal hari ini
// (WIB) dan store penjualan nyata.
//
// BUG-43: angka terjual tidak pernah diisi dari backend, jadi status dan sisa
// panen tidak berubah setelah penjualan dicatat. Perbaikannya: terjual dihitung
// dari stok batch penjualan (berat layak − stok tersedia).
//
// Bukti gagal di kode lama: tes BUG-42 memakai parameter `onCatatPenjualan`
// yang belum ada, dan tes BUG-43 mengharapkan sisa ikut berubah setelah
// penjualan — kode lama selalu menampilkan "Terjual 0 kg".
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/core/business_date.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/viewmodels/panen_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/penjualan_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/v2_penjualan_store.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_penjualan_data.dart';
import 'package:hidrosense_mobile/views/v2/connected/v2_panen_connected.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_option_row.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_select_field.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/harvest_fixture.dart';
import 'support/sales_fixture.dart';

const _user = SessionUser(
  id: '1',
  name: 'Mitra',
  username: 'mitra',
  role: 'petani',
  permissions: [
    'budidaya:read',
    'budidaya:write',
    'panen:read',
    'panen:write',
    'penjualan:read',
    'penjualan:write',
    'penyemaian:read',
    'inventaris:read',
  ],
);

ApiClient _api() {
  final api = ApiClient(
    MockClient(
      (_) async => http.Response(
        '{"data":[],"meta":{"page":1,"limit":20,"total":0,"total_pages":0}}',
        200,
      ),
    ),
    baseUri: Uri.parse('https://example.test/api/v1'),
  )..setTokens(accessToken: 'a', refreshToken: 'r');
  return api;
}

/// Menyiapkan viewmodel panen & penjualan yang sudah termuat, supaya tes tidak
/// bergantung pada timer/DB antrean sungguhan.
Future<
  ({FakeHarvestRepository harvest, FakeSalesRepository sales, PanenViewModel panen, PenjualanViewModel penjualan})
>
_siapkan({List<Map<String, dynamic>>? saleDetails}) async {
  final harvest = await loadedRepo();
  harvest.records = [saleHarvest()];
  final sales = FakeSalesRepository(_api());
  if (saleDetails != null) {
    sales.records = [saleRecord(details: saleDetails)];
  }
  final penjualan = PenjualanViewModel(
    sales,
    harvest,
    autoLoad: false,
    userId: '1',
  );
  await penjualan.refresh();
  final panen = PanenViewModel(
    harvest,
    (_) async {},
    canWrite: true,
    canReadBatches: true,
    userId: '1',
    autoLoad: false,
  );
  await panen.refresh();
  return (harvest: harvest, sales: sales, panen: panen, penjualan: penjualan);
}

Future<void> _pump(
  WidgetTester tester,
  ({
    FakeHarvestRepository harvest,
    FakeSalesRepository sales,
    PanenViewModel panen,
    PenjualanViewModel penjualan,
  })
  data,
) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = _api();
  addTearDown(api.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        panenViewModelProvider.overrideWith((ref) => data.panen),
        penjualanViewModelProvider.overrideWith((ref) => data.penjualan),
        v2PenjualanStoreProvider.overrideWith(
          (ref) => V2PenjualanApiStore(
            ref.watch(penjualanViewModelProvider.notifier),
          ),
        ),
        sessionProvider.overrideWith(
          (ref) =>
              SessionViewModel(api, initialState: const SessionState(user: _user)),
        ),
      ],
      child: MaterialApp(
        home: V2PanenConnectedDetailPage(
          item: v2PanenItemFromRecord(data.harvest.records.first),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('BUG-43: terjual dihitung dari stok batch penjualan', (
    tester,
  ) async {
    final data = await _siapkan(
      saleDetails: [
        saleDetailJson(harvestId: '1', quantity: '40.00', saleable: '100'),
      ],
    );
    await _pump(tester, data);

    expect(
      find.text('Terjual 40 kg. Sisa 60 kg.'),
      findsOneWidget,
      reason: 'BUG-43: sisa harus berkurang setelah ada penjualan',
    );
  });

  testWidgets('BUG-42: Catat penjualan memakai hari ini dan menyimpan', (
    tester,
  ) async {
    final data = await _siapkan();
    await _pump(tester, data);

    await tester.tap(find.text('Catat penjualan'));
    await tester.pumpAndSettle();

    expect(
      find.text(formatTanggalPenjualan(jakartaToday())),
      findsOneWidget,
      reason: 'BUG-42: tanggal awal harus hari ini WIB, bukan 15 Nov contoh',
    );

    // K-26: alur nyata mulai kosong, jadi isi dulu sebelum Simpan.
    await tester.enterText(find.byType(TextField).at(0), 'Warung Sari');
    await tester.enterText(find.byType(TextField).at(1), '10');
    await tester.enterText(find.byType(TextField).at(2), '5.000');
    await tester.tap(find.byType(V2SelectField).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(V2OptionRow).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(
      data.sales.drafts,
      hasLength(1),
      reason: 'BUG-42: "Simpan" harus menulis ke store, bukan mode pratinjau',
    );
  });
}