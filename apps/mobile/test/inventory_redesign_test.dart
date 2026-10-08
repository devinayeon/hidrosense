import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/inventory_record.dart';
import 'package:hidrosense_mobile/data/repositories/inventory_repository.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/data/services/inventory_cache.dart';
import 'package:hidrosense_mobile/viewmodels/connected_inventory_viewmodel.dart';
import 'package:hidrosense_mobile/views/components/inventaris_body.dart';
import 'package:hidrosense_mobile/views/pages/add_form_inventaris_page.dart';
import 'package:hidrosense_mobile/views/theme/app_theme.dart';
import 'package:hidrosense_mobile/views/widgets/inventory_illustration.dart';
import 'package:http/testing.dart';

InventoryRecord item(
  String id,
  String name,
  String category, {
  String balance = '1000',
  String? minimum = '100',
  bool active = true,
}) => InventoryRecord.fromJson({
  'id_inventaris': id,
  'public_id': null,
  'version': null,
  'id_jenis_inventaris': '1',
  'id_obat': null,
  'nama_barang': name,
  'satuan': 'gram',
  'stok_minimum': minimum,
  'status_aktif': active ? 1 : 0,
  'nama_jenis': category,
  'nama_obat': null,
  'saldo': balance,
});

class TestInventory extends ConnectedInventoryViewModel {
  TestInventory(ApiClient api, ConnectedInventoryState initial)
    : super(
        InventoryRepository(
          api,
          Completer<InventoryCache>().future,
          userId: '1',
        ),
        initialState: initial,
        autoLoad: false,
      );
  int refreshCalls = 0;
  void publish(ConnectedInventoryState next) => state = next;
  @override
  Future<void> refresh() async {
    refreshCalls++;
  }
}

Future<TestInventory> pumpInventory(
  WidgetTester tester,
  ConnectedInventoryState state, {
  bool dark = false,
  bool reduceMotion = false,
  Size viewport = const Size(390, 900),
}) async {
  await tester.binding.setSurfaceSize(viewport);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final api = ApiClient(
    MockClient((_) async => throw StateError('Unexpected API request')),
    baseUri: Uri.parse('https://example.test/api/v1'),
  );
  final model = TestInventory(api, state);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    api.close();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [connectedInventoryProvider.overrideWith((_) => model)],
      child: MaterialApp(
        theme: dark ? ThemeData.dark(useMaterial3: true) : AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: const Scaffold(appBar: InventoryHeader(), body: InventarisBody()),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  return model;
}

void main() {
  final romaine = item('1', 'Benih Selada Romaine', 'Benih');
  final nutrient = item(
    '2',
    'Nutrisi AB Mix Sayuran Daun',
    'Nutrisi',
    balance: '0.25',
    minimum: '1',
  );

  testWidgets('keyboard refresh and Escape dismiss the native stock sheet', (
    tester,
  ) async {
    final model = await pumpInventory(
      tester,
      ConnectedInventoryState(records: [romaine]),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(model.refreshCalls, 1);
    await tester.tap(find.text(romaine.name));
    await tester.pumpAndSettle();
    expect(find.text('Saldo: 1000 gram'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Saldo: 1000 gram'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('illustrations follow product override then category fallback', () {
    expect(
      InventoryIllustration.forItem(romaine),
      endsWith('item-romaine-seeds.png'),
    );
    expect(
      InventoryIllustration.forItem(item('3', 'Benih baru', 'Benih')),
      endsWith('category-seeds.png'),
    );
    expect(
      InventoryIllustration.forItem(item('4', 'Pupuk lain', 'Pupuk')),
      endsWith('item-abmix-nutrients.png'),
    );
    expect(
      InventoryIllustration.forItem(item('5', 'Barang lain', 'Khusus')),
      InventoryIllustration.overview,
    );
  });

  testWidgets(
    'search, category, clear filters and disappearing category remain usable',
    (tester) async {
      final model = await pumpInventory(
        tester,
        ConnectedInventoryState(
          records: [
            romaine,
            nutrient,
            item('3', 'Tidak aktif', 'Lain', active: false),
          ],
        ),
      );
      expect(find.text('2 barang · 2 kategori'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Nutrisi'));
      await tester.pumpAndSettle();
      expect(find.text(romaine.name), findsNothing);
      expect(find.text(nutrient.name), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'tidak cocok');
      await tester.pumpAndSettle();
      expect(find.text('Barang tidak ditemukan'), findsOneWidget);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Hapus filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus filter'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Nutrisi'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Nutrisi'));
      model.publish(ConnectedInventoryState(records: [romaine]));
      await tester.pumpAndSettle();
      expect(find.text(romaine.name), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Semua'))
            .selected,
        isTrue,
      );
      model.publish(ConnectedInventoryState(records: [romaine, nutrient]));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Semua'))
            .selected,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'refresh keeps exact stock visible and detail sheet opens and dismisses',
    (tester) async {
      final precise = item(
        '1',
        'Benih Selada Romaine',
        'Benih',
        balance: '9999999999.99',
      );
      final model = await pumpInventory(
        tester,
        ConnectedInventoryState(records: [precise]),
      );
      await tester.tap(find.byTooltip('Perbarui inventaris'));
      expect(model.refreshCalls, 1);
      model.publish(ConnectedInventoryState(records: [precise], loading: true));
      await tester.pump();
      expect(find.text('9999999999.99 gram'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      model.publish(ConnectedInventoryState(records: [precise]));
      await tester.pumpAndSettle();
      await tester.tap(find.text(precise.name));
      await tester.pumpAndSettle();
      expect(find.text('Saldo: 9999999999.99 gram'), findsOneWidget);
      expect(find.text('Stok minimum: 100 gram'), findsOneWidget);
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();
      expect(find.text('Saldo: 9999999999.99 gram'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'first run, initial loading and service failure have distinct states',
    (tester) async {
      final model = await pumpInventory(
        tester,
        const ConnectedInventoryState(loading: true),
      );
      expect(find.text('Memuat persediaan...'), findsOneWidget);
      expect(find.text('Persediaan dimulai di sini'), findsNothing);
      model.publish(const ConnectedInventoryState());
      await tester.pumpAndSettle();
      expect(find.text('Persediaan dimulai di sini'), findsOneWidget);
      model.publish(
        const ConnectedInventoryState(error: 'Layanan tidak tersedia.'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Inventaris belum dapat dimuat'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);
      await tester.ensureVisible(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coba lagi'));
      expect(model.refreshCalls, 1);
      model.publish(
        ConnectedInventoryState(
          records: [nutrient],
          error: 'Layanan tidak tersedia.',
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coba lagi'));
      expect(model.refreshCalls, 2);
      await tester.tap(find.text('Tambah barang'));
      await tester.pumpAndSettle();
      expect(find.byType(AddFormInventarisPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'narrow large text and dark mode retain quantities and reduce motion',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpInventory(
        tester,
        ConnectedInventoryState(records: [nutrient]),
        dark: true,
        reduceMotion: true,
        viewport: const Size(320, 1000),
      );
      await tester.scrollUntilVisible(
        find.text(nutrient.name),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(nutrient.name), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('0.25 gram'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Stok menipis'), findsOneWidget);
      await tester.pumpAndSettle();
      await tester.tap(find.text('0.25 gram'));
      await tester.pumpAndSettle();
      expect(find.text('Saldo: 0.25 gram'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'keyboard hides sticky action and clear search preserves selected category',
    (tester) async {
      await pumpInventory(
        tester,
        ConnectedInventoryState(records: [romaine, nutrient]),
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Benih'));
      await tester.enterText(find.byType(TextField), 'selada');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(find.text('Tambah barang'), findsNothing);
      await tester.tap(find.byTooltip('Hapus pencarian'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Benih'))
            .selected,
        isTrue,
      );
      expect(find.text(nutrient.name), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
