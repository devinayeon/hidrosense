// Regresi BUG-23: setelah "Terima" rekomendasi dengan potong stok, saldo di
// server berkurang, tetapi daftar/detail stok dan kartu "Stok menipis" di
// Beranda tetap menampilkan angka lama karena provider inventaris tidak dimuat
// ulang. Uji ini memastikan provider di-invalidate setelah terima berbahan.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/repositories/inventory_repository.dart';
import 'package:hidrosense_mobile/data/services/inventory_cache.dart';
import 'package:hidrosense_mobile/features/pest/data/pest_models.dart';
import 'package:hidrosense_mobile/features/pest/presentation/widgets/decision_sheets.dart';
import 'package:hidrosense_mobile/viewmodels/connected_inventory_viewmodel.dart';
import 'package:hidrosense_mobile/views/v2/widgets/v2_button.dart';

import 'pest_repository_test.dart' show recJson;
import 'support/damage_fixture.dart';

const _stock = [StockOption(id: '4', name: 'Benih test', unit: 'kg')];

/// Selama lembar terima terbuka, tombol "Terima" kartu berstatus loading
/// (spinner beranimasi terus) sehingga `pumpAndSettle` tidak pernah tenang.
/// Pakai jeda tetap agar pembangunan lembar selesai tanpa menunggu animasi.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// Penghitung pembangunan provider; harus mutable karena dibaca setelah aksi.
class _Counter {
  int value = 0;
}

Future<_Counter> _pumpCard(WidgetTester tester) async {
  final counter = _Counter();
  final api = apiFor((r) async => throw StateError('jaringan tidak dipakai'));
  addTearDown(api.close);
  final recommendation = PestRecommendation.fromJson(recJson());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        connectedInventoryProvider.overrideWith((ref) {
          counter.value++;
          return ConnectedInventoryViewModel(
            InventoryRepository(
              api,
              Completer<InventoryCache>().future,
              userId: '1',
            ),
            autoLoad: false,
          );
        }),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              // Pengamat provider yang sama dengan layar stok/Beranda; invalidasi
              // membuat provider dibangun ulang (counter naik).
              ref.watch(connectedInventoryProvider);
              return DecidableRecommendationCard(
                recommendation: recommendation,
                stock: _stock,
                onAccept: (id, {String? note, List<StockLineDraft> materials = const []}) async => null,
                onReject: (id, reason, {String? note}) async => null,
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return counter;
}

Future<void> _tapSheetTerima(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(BottomSheet),
      matching: find.widgetWithText(V2Button, 'Terima'),
    ),
  );
  // Pop-up konfirmasi ulang (Sesi 9) muncul setelah lembar terima ditutup;
  // kartu masih berstatus loading selama dialog terbuka, jadi jangan
  // pumpAndSettle dulu.
  await _settle(tester);
  await tester.tap(
    find.descendant(
      of: find.byType(Dialog),
      matching: find.widgetWithText(V2Button, 'Terima'),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('Terima'));
  await _settle(tester);
}

void main() {
  testWidgets('terima dengan potong stok memuat ulang daftar inventaris (BUG-23)', (tester) async {
    final counter = await _pumpCard(tester);
    expect(counter.value, 1);

    await _openSheet(tester);
    await tester.tap(find.text('Tidak memakai stok'));
    await _settle(tester);
    await tester.tap(find.text('Benih test (kg)').last);
    await _settle(tester);
    await tester.enterText(find.byType(TextField).first, '10');
    await _settle(tester);
    await _tapSheetTerima(tester);

    expect(tester.takeException(), isNull);
    expect(
      counter.value,
      2,
      reason: 'provider inventaris dibangun ulang setelah saldo terpotong',
    );
  });

  testWidgets('terima tanpa potong stok tidak memuat ulang daftar (BUG-23)', (tester) async {
    final counter = await _pumpCard(tester);
    await _openSheet(tester);
    await _tapSheetTerima(tester);

    expect(tester.takeException(), isNull);
    expect(counter.value, 1, reason: 'saldo tidak berubah, tidak perlu dimuat ulang');
  });
}
