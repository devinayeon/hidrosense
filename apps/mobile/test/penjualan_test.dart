import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/models/penjualan_model.dart';
import 'package:hidrosense_mobile/viewmodels/catat_penjualan_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/penjualan_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/views/components/catat_penjualan_body.dart';
import 'package:hidrosense_mobile/views/components/penjualan_body.dart';
import 'package:hidrosense_mobile/views/pages/catat_penjualan_page.dart';
import 'package:hidrosense_mobile/views/pages/penjualan_page.dart';
import 'package:hidrosense_mobile/views/theme/app_theme.dart';
import 'package:hidrosense_mobile/views/widgets/custom_dropdown_field.dart';
import 'package:hidrosense_mobile/views/widgets/penjualan_card.dart';
import 'package:hidrosense_mobile/views/widgets/row_button.dart';
import 'support/damage_fixture.dart';

void main() {
  group('PenjualanViewModel & Providers Unit Tests', () {
    test('initial state contains default penjualan list', () {
      final vm = PenjualanViewModel();
      expect(vm.state.length, 4);
      expect(vm.state.first.pembeli, 'Supermarket Jaya Makmur');
      expect(vm.state.first.isLunas, isTrue);
    });

    test('addPenjualan prepends new item to state', () {
      final vm = PenjualanViewModel();
      const newItem = PenjualanItem(
        id: 'new-1',
        pembeli: 'Restoran Sehat Sejahtera',
        tanggal: '15 Nov 2024',
        kuantitas: '15 Kg Selada',
        totalHarga: 375000,
        status: StatusPenjualan.lunas,
      );

      vm.addPenjualan(newItem);
      expect(vm.state.length, 5);
      expect(vm.state.first.id, 'new-1');
      expect(vm.state.first.pembeli, 'Restoran Sehat Sejahtera');
    });

    test('updatePenjualan updates existing item by id', () {
      final vm = PenjualanViewModel();
      final target = vm.state[1]; // id: '2', Toko Sayur Segar Ibu Ani
      expect(target.status, StatusPenjualan.belumLunas);

      final updated = target.copyWith(
        pembeli: 'Toko Sayur Segar Ibu Ani - Updated',
        status: StatusPenjualan.lunas,
        totalHarga: 600000,
      );

      vm.updatePenjualan(updated);
      expect(vm.state.length, 4);
      final found = vm.state.firstWhere((item) => item.id == '2');
      expect(found.pembeli, 'Toko Sayur Segar Ibu Ani - Updated');
      expect(found.status, StatusPenjualan.lunas);
      expect(found.totalHarga, 600000);
    });

    test('filteredPenjualanListProvider filters by search query and category', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Default: all 4 items
      expect(container.read(filteredPenjualanListProvider).length, 4);

      // Search query 'jaya'
      container.read(penjualanSearchQueryProvider.notifier).state = 'jaya';
      expect(container.read(filteredPenjualanListProvider).length, 1);
      expect(
        container.read(filteredPenjualanListProvider).first.pembeli,
        'Supermarket Jaya Makmur',
      );

      // Reset search, filter Lunas only
      container.read(penjualanSearchQueryProvider.notifier).state = '';
      container.read(penjualanFilterCategoryProvider.notifier).state =
          PenjualanFilterCategory.lunas;
      final lunasList = container.read(filteredPenjualanListProvider);
      expect(lunasList.length, 2);
      expect(lunasList.every((item) => item.isLunas), isTrue);

      // Filter Belum Lunas only
      container.read(penjualanFilterCategoryProvider.notifier).state =
          PenjualanFilterCategory.belumLunas;
      final belumLunasList = container.read(filteredPenjualanListProvider);
      expect(belumLunasList.length, 2);
      expect(belumLunasList.every((item) => !item.isLunas), isTrue);
    });

    test('totalPendapatanBulanIniProvider sums only lunas items', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Default list has 2 lunas items: 1.000.000 + 1.400.000 = 2.400.000
      expect(container.read(totalPendapatanBulanIniProvider), 2400000.0);

      // After updating item '2' (500.000) to lunas, total becomes 2.900.000
      final item2 = container.read(penjualanViewModelProvider)[1];
      container
          .read(penjualanViewModelProvider.notifier)
          .updatePenjualan(item2.copyWith(status: StatusPenjualan.lunas));
      expect(container.read(totalPendapatanBulanIniProvider), 2900000.0);
    });

    test('CatatPenjualanViewModel validates all business requirements', () {
      final vm = CatatPenjualanViewModel();

      // 1. Initial validation message: buyer is empty
      expect(vm.validationMessage(), 'Nama pembeli wajib diisi.');
      expect(vm.validateForm(), isFalse);

      // 2. Set buyer -> missing batch
      vm.setPembeli('Supermarket Segar');
      expect(vm.validationMessage(), 'Pilih hasil panen terlebih dahulu.');

      // 3. Set batch -> berat <= 0
      const testBatch = BatchPanen(
        id: 'b1',
        nama: 'Batch #04 - Selada Grand Rapids',
        stokTersedia: 100.0,
      );
      vm.setBatch(testBatch);
      expect(vm.validationMessage(), 'Berat jual harus lebih dari 0 Kg.');

      // 4. Set berat exceeding stock
      vm.setBerat(150.0);
      expect(
        vm.validationMessage(),
        'Berat melebihi stok tersedia (100 Kg).',
      );

      // 5. Valid berat -> harga <= 0
      vm.setBerat(20.0);
      expect(vm.validationMessage(), 'Harga per Kg harus lebih dari 0.');

      // 6. Valid harga -> status missing
      vm.setHargaPerKg(25000.0);
      expect(vm.validationMessage(), 'Status pembayaran wajib dipilih.');
      expect(vm.state.totalEstimasi, 500000.0);

      // 7. Complete valid form
      vm.setStatus(StatusPenjualan.lunas);
      expect(vm.validationMessage(), isNull);
      expect(vm.validateForm(), isTrue);
    });
  });

  group('Widget Tests: Fitur Pencatatan Penjualan (Petani)', () {
    late ApiClient api;

    setUp(() {
      api = apiFor((_) async => throw StateError('Unexpected API'));
    });

    tearDown(() {
      api.close();
    });

    Widget createTestApp({
      Widget? child,
      List<Override> overrides = const [],
    }) {
      return ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          sessionProvider.overrideWith(
            (_) => SessionViewModel(
              api,
              initialState: const SessionState(user: farmer),
            ),
          ),
          ...overrides,
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: child ?? const PenjualanPage(),
        ),
      );
    }

    testWidgets('Melihat Data Penjualan: Header, Revenue, Cards, Search & Filter', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // 1. Verify Header and Revenue Card
      expect(find.text('Penjualan'), findsOneWidget);
      expect(find.text('Total Pendapatan Bulan Ini'), findsOneWidget);
      expect(find.text('Rp 2.400.000'), findsOneWidget);
      expect(
        find.text('Dari total 4 transaksi penjualan terlaksana'),
        findsOneWidget,
      );

      // 2. Verify all initial cards are rendered
      expect(find.byType(PenjualanCard), findsNWidgets(4));
      expect(find.text('Supermarket Jaya Makmur'), findsOneWidget);
      expect(find.text('Toko Sayur Segar Ibu Ani'), findsOneWidget);

      // 3. Test Search Bar: Cari 'Resto'
      await tester.enterText(
        find.ancestor(
          of: find.text('Cari pembeli...'),
          matching: find.byType(TextField),
        ),
        'Resto',
      );
      await tester.pumpAndSettle();

      expect(find.byType(PenjualanCard), findsOneWidget);
      expect(find.text('Resto Green Salad'), findsOneWidget);
      expect(find.text('Supermarket Jaya Makmur'), findsNothing);

      // Clear search
      await tester.enterText(
        find.ancestor(
          of: find.text('Cari pembeli...'),
          matching: find.byType(TextField),
        ),
        '',
      );
      await tester.pumpAndSettle();
      expect(find.byType(PenjualanCard), findsNWidgets(4));

      // 4. Test Filter Status: Open Filter BottomSheet
      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();

      expect(find.text('Filter Status Penjualan'), findsOneWidget);
      expect(find.text('Semua Status'), findsOneWidget);
      expect(find.text('Lunas'), findsOneWidget);
      expect(find.text('Belum Lunas'), findsOneWidget);

      // Select 'Belum Lunas'
      await tester.tap(find.text('Belum Lunas'));
      await tester.pumpAndSettle();

      expect(find.byType(PenjualanCard), findsNWidgets(2));
      expect(find.text('Toko Sayur Segar Ibu Ani'), findsOneWidget);
      expect(find.text('Catering Healthy Meal'), findsOneWidget);
      expect(find.text('Supermarket Jaya Makmur'), findsNothing);

      // Re-open Filter and select 'Semua Status'
      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Semua Status'));
      await tester.pumpAndSettle();

      expect(find.byType(PenjualanCard), findsNWidgets(4));
    });

    testWidgets('Menambahkan Data Penjualan: Validation and Successful Save', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.text('+ Catat Penjualan Baru'), findsOneWidget);
      await tester.tap(find.text('+ Catat Penjualan Baru'));
      await tester.pumpAndSettle();

      expect(find.text('Catat Penjualan'), findsOneWidget);
      expect(find.text('Simpan Penjualan'), findsOneWidget);

      // 1. Submit empty form -> displays error SnackBar
      await tester.ensureVisible(find.text('Simpan Penjualan'));
      await tester.tap(find.text('Simpan Penjualan'));
      await tester.pumpAndSettle();
      expect(find.text('Nama pembeli wajib diisi.'), findsOneWidget);

      // Clear SnackBar so it does not block the bottom button
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold))).clearSnackBars();
      await tester.pumpAndSettle();

      // 2. Fill Buyer Name
      final pembeliField = find.ancestor(
        of: find.text('Nama Pembeli / Klien'),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(pembeliField, 'Resto Organik Nusantara');
      await tester.pumpAndSettle();

      // Submit without batch -> displays error SnackBar
      await tester.ensureVisible(find.text('Simpan Penjualan'));
      await tester.tap(find.text('Simpan Penjualan'));
      await tester.pumpAndSettle();
      expect(find.text('Pilih hasil panen terlebih dahulu.'), findsOneWidget);

      // Clear SnackBar
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold))).clearSnackBars();
      await tester.pumpAndSettle();

      // 3. Select Batch Panen
      await tester.tap(find.widgetWithText(CustomDropdownField, 'Pilih Hasil Panen'));
      await tester.pumpAndSettle();
      expect(find.text('Batch #04 - Selada Grand Rapids'), findsWidgets);
      await tester.tap(find.text('Batch #04 - Selada Grand Rapids').last);
      await tester.pumpAndSettle();

      // 4. Test exceeding stock limit (Batch #04 has 120 Kg)
      final beratField = find.ancestor(
        of: find.text('Berat Jual (Kg)'),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(beratField, '150');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Simpan Penjualan'));
      await tester.tap(find.text('Simpan Penjualan'));
      await tester.pumpAndSettle();
      expect(
        find.text('Berat melebihi stok tersedia (120 Kg).'),
        findsOneWidget,
      );

      // Clear SnackBar
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold))).clearSnackBars();
      await tester.pumpAndSettle();

      // 5. Enter valid weight and price
      await tester.enterText(beratField, '15');
      final hargaField = find.ancestor(
        of: find.text('Harga Per Kg (Rp)'),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(hargaField, '20000');
      await tester.pumpAndSettle();

      // Verify Estimasi Total Card calculation: 15 * 20,000 = Rp 300.000
      expect(find.text('Rp 300.000'), findsOneWidget);

      // 6. Select Status Pembayaran -> 'Lunas'
      await tester.tap(find.widgetWithText(CustomDropdownField, 'Status Pembayaran'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lunas').last);
      await tester.pumpAndSettle();

      // 7. Save valid form
      await tester.ensureVisible(find.text('Simpan Penjualan'));
      await tester.tap(find.text('Simpan Penjualan'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('Penjualan berhasil dicatat!'), findsOneWidget);
      expect(find.text('Penjualan'), findsOneWidget);
      expect(find.text('Resto Organik Nusantara'), findsOneWidget);
      expect(find.byType(PenjualanCard), findsNWidgets(5));
    });

    testWidgets('Mengubah Data Penjualan: Card Tap, Pre-fill, Edit, and Update State', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Verify initial cards and state
      expect(find.text('Toko Sayur Segar Ibu Ani'), findsOneWidget);
      expect(find.text('Rp 2.400.000'), findsOneWidget);

      // 1. Tap on second card ('Toko Sayur Segar Ibu Ani' - Belum Lunas, Rp 500.000)
      await tester.tap(find.text('Toko Sayur Segar Ibu Ani'));
      await tester.pumpAndSettle();

      // 2. Verify Edit Page renders with prefilled values
      expect(find.text('Edit Penjualan'), findsOneWidget);
      expect(find.text('Simpan Perubahan'), findsOneWidget);
      expect(find.text('Toko Sayur Segar Ibu Ani'), findsOneWidget);
      expect(find.text('25'), findsOneWidget);
      expect(find.text('20000'), findsOneWidget);

      // 3. Edit buyer name
      final pembeliField = find.ancestor(
        of: find.text('Nama Pembeli / Klien'),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(
        pembeliField,
        'Toko Sayur Segar Ibu Ani (Lunas)',
      );
      await tester.pumpAndSettle();

      // 4. Update status from Belum Lunas to Lunas
      await tester.tap(find.widgetWithText(CustomDropdownField, 'Status Pembayaran'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lunas').last);
      await tester.pumpAndSettle();

      // 5. Submit Changes
      await tester.ensureVisible(find.text('Simpan Perubahan'));
      await tester.tap(find.text('Simpan Perubahan'));
      await tester.pumpAndSettle();

      // 6. Verify success feedback and popped back to PenjualanPage
      expect(find.text('Penjualan berhasil diperbarui!'), findsOneWidget);
      expect(find.text('Penjualan'), findsOneWidget);

      // 7. Verify updated data displayed in list
      expect(find.text('Toko Sayur Segar Ibu Ani (Lunas)'), findsOneWidget);

      // 8. Verify total revenue recalculation (Rp 2.400.000 + Rp 500.000 = Rp 2.900.000)
      expect(find.text('Rp 2.900.000'), findsOneWidget);
    });
  });
}
