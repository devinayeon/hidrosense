import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/core/business_date.dart';
import 'package:hidrosense_mobile/data/models/sale_record.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/models/penjualan_model.dart';
import 'package:hidrosense_mobile/viewmodels/catat_penjualan_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/panen_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/penjualan_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/views/pages/penjualan_page.dart';
import 'package:hidrosense_mobile/views/theme/app_theme.dart';
import 'package:hidrosense_mobile/views/widgets/custom_dropdown_field.dart';
import 'package:hidrosense_mobile/views/widgets/penjualan_card.dart';

import 'support/damage_fixture.dart';
import 'support/harvest_fixture.dart';
import 'support/sales_fixture.dart';

void main() {
  group('PenjualanViewModel', () {
    late FakeSalesRepository sales;
    late FakeHarvestRepository harvest;

    setUp(() {
      sales = FakeSalesRepository(
        salesApi((_) async => throw StateError('Unexpected API')),
      );
      harvest = FakeHarvestRepository(harvestApi((_) async => harvestPage([])));
    });

    test(
      'loads real sales, computes remaining stock and this-month revenue',
      () async {
        harvest.records = [
          saleHarvest(id: '1', layak: '100.00'),
          saleHarvest(id: '2', layak: '50.00'),
        ];
        sales.records = [
          saleRecord(
            id: '1',
            date: '2026-09-25',
            status: 'lunas',
            details: [
              saleDetailJson(
                id: '1',
                harvestId: '2',
                quantity: '5.00',
                price: '20000.00',
              ),
            ],
          ),
          saleRecord(
            id: '2',
            date: '2026-08-30',
            buyer: 'Toko Lama',
            status: 'lunas',
            details: [
              saleDetailJson(
                id: '2',
                harvestId: '2',
                quantity: '10.00',
                price: '20000.00',
              ),
            ],
          ),
        ];
        final vm = PenjualanViewModel(sales, harvest, autoLoad: false);
        addTearDown(vm.dispose);
        await vm.refresh();

        expect(vm.state.items.length, 2);
        expect(vm.state.batches.length, 2);
        final second = vm.state.batches.firstWhere((batch) => batch.id == '2');
        expect(second.stokTersedia, 35.0);
        expect(vm.state.items.first.kuantitas, '5 Kg');
        expect(vm.state.items.first.totalHarga, 100000.0);
      },
    );

    test(
      'createSale sends one line and reduces the chosen batch stock',
      () async {
        harvest.records = [saleHarvest(id: '1', layak: '100.00')];
        final vm = PenjualanViewModel(sales, harvest, autoLoad: false);
        addTearDown(vm.dispose);
        await vm.refresh();

        final draft = SalesDraft(
          date: '2026-09-25',
          buyer: 'Resto Baru',
          status: 'lunas',
          harvestId: '1',
          quantity: 12.5,
          price: 20000,
        );
        final item = await vm.createSale(draft);

        expect(item.pembeli, 'Resto Baru');
        expect(item.totalHarga, 250000.0);
        expect(sales.drafts.single.buyer, 'Resto Baru');
        expect(sales.keys.single.length, 36);
        expect(vm.state.items.length, 1);
        expect(
          vm.state.batches.firstWhere((batch) => batch.id == '1').stokTersedia,
          87.5,
        );
      },
    );

    test(
      'updateSale excludes its old quantity and refreshes the list',
      () async {
        harvest.records = [saleHarvest(id: '1', layak: '100.00')];
        sales.records = [
          saleRecord(
            id: '1',
            date: '2026-09-25',
            details: [
              saleDetailJson(
                id: '1',
                harvestId: '1',
                quantity: '10.00',
                price: '20000.00',
              ),
            ],
          ),
        ];
        final vm = PenjualanViewModel(sales, harvest, autoLoad: false);
        addTearDown(vm.dispose);
        await vm.refresh();
        final existing = vm.state.items.single;

        final updated = await vm.updateSale(
          existing,
          SalesDraft(
            date: '2026-09-25',
            buyer: 'Supermarket Jaya',
            status: 'lunas',
            harvestId: '1',
            quantity: 15,
            price: 20000,
          ),
        );

        expect(updated.version, '2');
        expect(updated.totalHarga, 300000.0);
        expect(sales.updateKeys.single.length, 36);
        expect(vm.state.items.single.totalHarga, 300000.0);
        expect(
          vm.state.batches.firstWhere((batch) => batch.id == '1').stokTersedia,
          85.0,
        );
      },
    );

    test('write refresh supersedes an older in-flight list response', () async {
      harvest.records = [saleHarvest(id: '1', layak: '100.00')];
      final vm = PenjualanViewModel(sales, harvest, autoLoad: false);
      addTearDown(vm.dispose);
      await vm.refresh();

      final pending = Completer<List<SaleRecord>>();
      sales.onList = () => pending.future;
      final olderRefresh = vm.refresh();
      sales.onList = null;

      final item = await vm.createSale(
        SalesDraft(
          date: '2026-09-25',
          buyer: 'Baru',
          status: 'lunas',
          harvestId: '1',
          quantity: 5,
          price: 20000,
        ),
      );
      pending.complete(const []);
      await olderRefresh;

      expect(vm.state.items.any((entry) => entry.id == item.id), isTrue);
      expect(vm.state.items.single.totalHarga, 100000.0);
    });

    test('harvest failure keeps sales and known stock visible', () async {
      harvest.records = [saleHarvest(id: '1', layak: '100.00')];
      sales.records = [
        saleRecord(
          id: '1',
          details: [
            saleDetailJson(
              id: '1',
              harvestId: '1',
              quantity: '5.00',
              price: '20000.00',
            ),
          ],
        ),
      ];
      final vm = PenjualanViewModel(sales, harvest, autoLoad: false);
      addTearDown(vm.dispose);
      await vm.refresh();

      harvest.readError = const ApiException(
        500,
        'SERVER',
        'Panen gagal dimuat.',
      );
      await vm.refresh();

      expect(vm.state.items, hasLength(1));
      expect(vm.state.salesLoaded, isTrue);
      expect(
        vm.state.batches.firstWhere((batch) => batch.id == '1').stokTersedia,
        95.0,
      );
      expect(vm.state.error, 'Panen gagal dimuat.');
    });

    test('empty sales remain loaded when harvest fails', () async {
      harvest.readError = const ApiException(
        500,
        'SERVER',
        'Panen gagal dimuat.',
      );
      final vm = PenjualanViewModel(sales, harvest, autoLoad: false);
      addTearDown(vm.dispose);
      await vm.refresh();

      expect(vm.state.items, isEmpty);
      expect(vm.state.salesLoaded, isTrue);
      expect(vm.state.error, 'Panen gagal dimuat.');
    });

    test(
      'failed refresh keeps optimistic data and exposes a retry error',
      () async {
        harvest.records = [saleHarvest(id: '1', layak: '100.00')];
        sales.records = [
          saleRecord(
            id: '1',
            details: [
              saleDetailJson(
                id: '1',
                harvestId: '1',
                quantity: '5.00',
                price: '20000.00',
              ),
            ],
          ),
        ];
        final vm = PenjualanViewModel(sales, harvest, autoLoad: false);
        addTearDown(vm.dispose);
        await vm.refresh();
        final item = await vm.createSale(
          SalesDraft(
            date: '2026-09-25',
            buyer: 'Baru',
            status: 'lunas',
            harvestId: '1',
            quantity: 1,
            price: 20000,
          ),
        );

        sales.loadError = const ApiException(500, 'SERVER', 'Gagal memuat.');
        await vm.refresh();
        expect(vm.state.items.any((entry) => entry.id == item.id), isTrue);
        expect(vm.state.error, 'Gagal memuat.');
      },
    );
  });

  group('Penjualan providers', () {
    test('filter and month revenue use the loaded state', () async {
      final api = apiFor((_) async => throw StateError('Unexpected API'));
      addTearDown(api.close);
      final sales = FakeSalesRepository(
        salesApi((_) async => throw StateError('Unexpected API')),
      );
      final harvest = FakeHarvestRepository(
        harvestApi((_) async => harvestPage([])),
      );
      harvest.records = [saleHarvest(id: '1', layak: '100.00')];
      sales.records = [
        saleRecord(
          id: '1',
          date: '2026-09-25',
          buyer: 'Supermarket Jaya',
          status: 'lunas',
          details: [
            saleDetailJson(
              id: '1',
              harvestId: '1',
              quantity: '5.00',
              price: '20000.00',
            ),
          ],
        ),
        saleRecord(
          id: '2',
          date: '2026-08-30',
          buyer: 'Toko Lama',
          status: 'lunas',
          details: [
            saleDetailJson(
              id: '2',
              harvestId: '1',
              quantity: '10.00',
              price: '20000.00',
            ),
          ],
        ),
      ];
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          sessionProvider.overrideWith(
            (ref) => SessionViewModel(
              api,
              initialState: const SessionState(user: farmer),
            ),
          ),
          salesRepositoryProvider.overrideWithValue(sales),
          harvestRepositoryProvider.overrideWithValue(harvest),
          penjualanClockProvider.overrideWithValue(
            () => DateTime.utc(2026, 9, 15),
          ),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(penjualanViewModelProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(penjualanViewModelProvider.notifier).refresh();

      expect(container.read(totalPendapatanBulanIniProvider), 100000.0);
      container.read(penjualanSearchQueryProvider.notifier).state = 'super';
      expect(container.read(filteredPenjualanListProvider).length, 1);
      container.read(penjualanSearchQueryProvider.notifier).state = '';
      container.read(penjualanFilterCategoryProvider.notifier).state =
          PenjualanFilterCategory.lunas;
      expect(container.read(filteredPenjualanListProvider).length, 2);
    });
  });

  group('CatatPenjualanViewModel', () {
    test('validates real stock, dates, and decimals', () {
      final today = jakartaToday();
      final harvestDate = apiDate(today.subtract(const Duration(days: 5)));
      final vm = CatatPenjualanViewModel(initialDate: today);
      addTearDown(vm.dispose);
      final batch = BatchPanen(
        id: '1',
        nama: 'Panen #1',
        stokTersedia: 100,
        tanggalPanen: harvestDate,
      );

      expect(vm.validationMessage(), 'Nama pembeli wajib diisi.');
      vm.setPembeli('Pembeli');
      expect(vm.validationMessage(), 'Pilih hasil panen terlebih dahulu.');
      vm.setBatch(batch);
      expect(vm.validationMessage(), 'Berat jual harus lebih dari 0 Kg.');
      vm.setBerat(150);
      expect(vm.validationMessage(), 'Berat melebihi stok tersedia (100 Kg).');
      vm.setBerat(20);
      expect(vm.validationMessage(), 'Harga per Kg harus lebih dari 0.');
      vm.setHargaPerKg(25000);
      expect(vm.validationMessage(), 'Status pembayaran wajib dipilih.');
      vm.setStatus(StatusPenjualan.lunas);
      expect(vm.validationMessage(), isNull);

      vm.setTanggal(today.subtract(const Duration(days: 10)));
      expect(
        vm.validationMessage(),
        'Tanggal transaksi mendahului tanggal panen.',
      );
      vm.setTanggal(today.add(const Duration(days: 1)));
      expect(
        vm.validationMessage(),
        'Tanggal transaksi tidak boleh di masa depan.',
      );
      vm.setTanggal(today);
      vm.setBerat(1.001);
      expect(vm.validationMessage(), 'Berat jual maksimal dua angka desimal.');
    });
  });

  group('Widget: penjualan tersambung', () {
    late ApiClient api;
    late FakeSalesRepository sales;
    late FakeHarvestRepository harvest;
    late String harvestDate;

    setUp(() {
      api = apiFor((_) async => throw StateError('Unexpected API'));
      sales = FakeSalesRepository(
        salesApi((_) async => throw StateError('Unexpected API')),
      );
      harvest = FakeHarvestRepository(harvestApi((_) async => harvestPage([])));
      final today = jakartaToday();
      harvestDate = apiDate(today.subtract(const Duration(days: 10)));
      harvest.records = [
        saleHarvest(id: '1', date: harvestDate, layak: '100.00'),
        saleHarvest(
          id: '2',
          date: harvestDate,
          layak: '50.00',
          transferId: '2',
          count: 25,
        ),
      ];
      sales.records = [
        saleRecord(
          id: '1',
          buyer: 'Supermarket Jaya',
          date: apiDate(today.subtract(const Duration(days: 5))),
          status: 'lunas',
          details: [
            saleDetailJson(
              id: '1',
              harvestId: '2',
              harvestDate: harvestDate,
              quantity: '5.00',
              price: '20000.00',
            ),
          ],
        ),
        saleRecord(
          id: '2',
          buyer: 'Toko Sayur Segar',
          date: apiDate(today.subtract(const Duration(days: 7))),
          status: 'belum_lunas',
          details: [
            saleDetailJson(
              id: '2',
              harvestId: '2',
              harvestDate: harvestDate,
              quantity: '10.00',
              price: '20000.00',
            ),
          ],
        ),
      ];
    });

    tearDown(() => api.close());

    Widget app() => ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        sessionProvider.overrideWith(
          (ref) => SessionViewModel(
            api,
            initialState: const SessionState(user: farmer),
          ),
        ),
        salesRepositoryProvider.overrideWithValue(sales),
        harvestRepositoryProvider.overrideWithValue(harvest),
        penjualanClockProvider.overrideWithValue(() => DateTime.now()),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const PenjualanPage(),
      ),
    );

    testWidgets('menampilkan data, pencarian, filter, dan total bulan ini', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.byType(PenjualanCard), findsNWidgets(2));
      expect(find.text('Supermarket Jaya'), findsOneWidget);
      expect(find.text('Toko Sayur Segar'), findsOneWidget);
      expect(find.text('Rp 100.000'), findsNWidgets(2));

      await tester.enterText(
        find.ancestor(
          of: find.text('Cari pembeli...'),
          matching: find.byType(TextField),
        ),
        'Toko',
      );
      await tester.pumpAndSettle();
      expect(find.byType(PenjualanCard), findsOneWidget);

      await tester.enterText(
        find.ancestor(
          of: find.text('Cari pembeli...'),
          matching: find.byType(TextField),
        ),
        '',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lunas'));
      await tester.pumpAndSettle();
      expect(find.byType(PenjualanCard), findsOneWidget);
      expect(find.text('Supermarket Jaya'), findsOneWidget);

      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Semua Status'));
      await tester.pumpAndSettle();
      expect(find.byType(PenjualanCard), findsNWidgets(2));
    });

    testWidgets('empty sales stay visible when harvest loading fails', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      sales.records = [];
      harvest.readError = const ApiException(
        500,
        'SERVER',
        'Panen gagal dimuat.',
      );

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.text('Gagal memuat penjualan.'), findsNothing);
      expect(find.text('Tidak ada data penjualan.'), findsOneWidget);
      expect(find.text('Panen gagal dimuat.'), findsOneWidget);
      expect(find.text('+ Catat Penjualan Baru'), findsOneWidget);
    });

    testWidgets('membuat penjualan baru dan menyegarkan stok serta total', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('+ Catat Penjualan Baru'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Simpan Penjualan'));
      await tester.tap(find.text('Simpan Penjualan'));
      await tester.pumpAndSettle();
      expect(find.text('Nama pembeli wajib diisi.'), findsOneWidget);
      ScaffoldMessenger.of(
        tester.element(find.byType(Scaffold)),
      ).clearSnackBars();
      await tester.pumpAndSettle();

      await tester.enterText(
        find.ancestor(
          of: find.text('Nama Pembeli / Klien'),
          matching: find.byType(TextFormField),
        ),
        'Resto Baru',
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(CustomDropdownField, 'Pilih Hasil Panen'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Panen #1').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.ancestor(
          of: find.text('Berat Jual (Kg)'),
          matching: find.byType(TextFormField),
        ),
        '15',
      );
      await tester.enterText(
        find.ancestor(
          of: find.text('Harga Per Kg (Rp)'),
          matching: find.byType(TextFormField),
        ),
        '20000',
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(CustomDropdownField, 'Status Pembayaran'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lunas').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Simpan Penjualan'));
      await tester.tap(find.text('Simpan Penjualan'));
      await tester.pumpAndSettle();

      expect(find.text('Penjualan berhasil dicatat!'), findsOneWidget);
      expect(find.text('Resto Baru'), findsOneWidget);
      expect(find.byType(PenjualanCard), findsNWidgets(3));
      expect(find.text('Rp 400.000'), findsOneWidget);
      expect(sales.keys.length, 1);
    });

    testWidgets('mengubah penjualan lewat data server, bukan state lokal', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toko Sayur Segar'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Penjualan'), findsOneWidget);
      await tester.enterText(
        find.ancestor(
          of: find.text('Nama Pembeli / Klien'),
          matching: find.byType(TextFormField),
        ),
        'Toko Sayur Segar (Lunas)',
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(CustomDropdownField, 'Status Pembayaran'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lunas').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Simpan Perubahan'));
      await tester.tap(find.text('Simpan Perubahan'));
      await tester.pumpAndSettle();

      expect(find.text('Penjualan berhasil diperbarui!'), findsOneWidget);
      expect(find.text('Toko Sayur Segar (Lunas)'), findsOneWidget);
      expect(find.text('Rp 300.000'), findsOneWidget);
      expect(sales.updateKeys.length, 1);
    });
  });
}
