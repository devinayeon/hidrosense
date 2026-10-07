import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/inventory_record.dart';
import 'package:hidrosense_mobile/data/repositories/inventory_repository.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/data/services/inventory_cache.dart';
import 'package:hidrosense_mobile/viewmodels/connected_inventory_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/views/pages/connected_inventory_page.dart';
import 'package:hidrosense_mobile/views/theme/app_theme.dart';
import 'package:http/testing.dart';

InventoryRecord inventory({required String balance, String? minimum = '1'}) =>
    InventoryRecord.fromJson({
      'id_inventaris': '1',
      'public_id': null,
      'version': null,
      'id_jenis_inventaris': '1',
      'id_obat': null,
      'nama_barang': 'Pupuk Uji',
      'satuan': 'kg',
      'stok_minimum': minimum,
      'status_aktif': 1,
      'nama_jenis': 'Pupuk',
      'nama_obat': null,
      'saldo': balance,
    });

Future<void> pumpInventory(WidgetTester tester, InventoryRecord item) async {
  final api = ApiClient(
    MockClient((_) async => throw StateError('Unexpected API request')),
    baseUri: Uri.parse('https://example.test/api/v1'),
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    api.close();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith((ref) => SessionViewModel(api)),
        connectedInventoryProvider.overrideWith(
          (ref) => ConnectedInventoryViewModel(
            InventoryRepository(
              api,
              Completer<InventoryCache>().future,
              userId: '1',
            ),
            initialState: ConnectedInventoryState(records: [item]),
            autoLoad: false,
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ConnectedInventoryPage(),
      ),
    ),
  );
}

void expectHeadlineBalance(WidgetTester tester, String label) {
  final text = tester.widget<Text>(find.text(label));
  expect(text.style, AppTypography.tabular(AppTypography.headline));
  expect(
    text.style!.fontFeatures,
    contains(const FontFeature.tabularFigures()),
  );
}

void expectWarningBadge(WidgetTester tester, {Finder? within}) {
  final label = within == null
      ? find.text('Stok Menipis')
      : find.descendant(of: within, matching: find.text('Stok Menipis'));
  final badge = find
      .ancestor(of: label, matching: find.byType(Container))
      .first;
  final decoration =
      tester.widget<Container>(badge).decoration! as BoxDecoration;
  expect(decoration.color, AppColors.warningBg);
  expect(decoration.border, Border.all(color: AppColors.warningOrange));
  expect(decoration.borderRadius, BorderRadius.circular(AppRadius.badge));
  final semantics = find.bySemanticsLabel('Stok Menipis');
  expect(
    within == null
        ? semantics
        : find.descendant(of: within, matching: semantics),
    findsOneWidget,
  );
}

void main() {
  testWidgets(
    'saldo desimal tetap presisi dan headline tabular di daftar/detail',
    (tester) async {
      await pumpInventory(tester, inventory(balance: '9999999999.99'));

      expectHeadlineBalance(tester, '9999999999.99 kg');
      await tester.tap(find.text('Pupuk Uji'));
      await tester.pumpAndSettle();
      expectHeadlineBalance(tester, 'Saldo: 9999999999.99 kg');
      expect(find.text('Stok minimum: 1 kg'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Stok mencukupi'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('di bawah minimum menampilkan badge oranye di daftar/detail', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpInventory(tester, inventory(balance: '0.25'));

      expectHeadlineBalance(tester, '0.25 kg');
      expectWarningBadge(tester);
      expect(find.text('Stok habis'), findsNothing);
      await tester.tap(find.text('Pupuk Uji'));
      await tester.pumpAndSettle();
      expectHeadlineBalance(tester, 'Saldo: 0.25 kg');
      expectWarningBadge(tester, within: find.byType(AlertDialog));
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  for (final stockCase in [
    (balance: '0.00', minimum: '1', label: 'Stok habis'),
    (balance: '0', minimum: null, label: 'Stok habis'),
    (balance: '1', minimum: '1', label: 'Stok mencukupi'),
    (balance: '1.01', minimum: '1', label: 'Stok mencukupi'),
    (balance: '0.25', minimum: null, label: 'Stok tersedia'),
  ]) {
    testWidgets(
      'saldo ${stockCase.balance}, minimum ${stockCase.minimum}: ${stockCase.label}',
      (tester) async {
        await pumpInventory(
          tester,
          inventory(balance: stockCase.balance, minimum: stockCase.minimum),
        );

        expect(find.text(stockCase.label), findsOneWidget);
        expect(find.text('Stok Menipis'), findsNothing);
        await tester.tap(find.text('Pupuk Uji'));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(stockCase.label),
          ),
          findsOneWidget,
        );
        expect(find.text('Stok Menipis'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('saldo dan badge muat di layar sempit dengan teks diperbesar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(240, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpInventory(tester, inventory(balance: '0.25'));

    expect(find.text('0.25 kg'), findsOneWidget);
    expect(find.text('Stok Menipis'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
