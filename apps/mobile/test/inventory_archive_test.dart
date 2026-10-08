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
import 'package:hidrosense_mobile/views/components/inventaris_body.dart';
import 'package:hidrosense_mobile/views/theme/app_theme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'support/damage_fixture.dart';

class _ArchiveViewModel extends ConnectedInventoryViewModel {
  _ArchiveViewModel(super.repo, InventoryRecord item)
    : super(
        autoLoad: false,
        initialState: ConnectedInventoryState(records: [item]),
      );
  Future<void>? operation;
  @override
  Future<void> deactivateItem(String id) =>
      operation = super.deactivateItem(id);
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final item = InventoryRecord.fromJson({
    'id_inventaris': '1',
    'public_id': null,
    'version': null,
    'id_jenis_inventaris': '1',
    'id_obat': null,
    'nama_barang': 'Benih Romaine',
    'satuan': 'gram',
    'stok_minimum': '5',
    'status_aktif': 1,
    'nama_jenis': 'Benih',
    'nama_obat': null,
    'saldo': '100',
  });
  for (final fail in [false, true]) {
    testWidgets(
      'archive calls API once and ${fail ? 'preserves items on failure' : 'refreshes state and cache once'} after sheet closes',
      (tester) async {
        final db = await tester.runAsync(
          () => databaseFactoryFfi.openDatabase(
            inMemoryDatabasePath,
            options: OpenDatabaseOptions(
              version: 1,
              onCreate: InventoryCache.createSchema,
            ),
          ),
        );
        final cache = InventoryCache(db!);
        addTearDown(cache.close);
        var writes = 0;
        var reads = 0;
        final api = apiFor((request) async {
          if (request.method == 'POST') {
            writes++;
            expect(request.url.path, '/api/v1/inventaris/1/deactivate');
            if (fail) throw const ApiException(500, 'FAILED', 'Arsip gagal');
            return reply({'data': {}});
          }
          reads++;
          return pageReply([]);
        });
        addTearDown(api.close);
        final repo = InventoryRepository(api, Future.value(cache), userId: '1');
        final vm = _ArchiveViewModel(repo, item);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(api),
              sessionProvider.overrideWith(
                (_) => SessionViewModel(
                  api,
                  initialState: const SessionState(user: farmer),
                ),
              ),
              connectedInventoryProvider.overrideWith((_) => vm),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const Scaffold(body: InventarisBody()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(item.name));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Arsipkan'));
        await tester.tap(find.text('Arsipkan'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Arsipkan'));
        await tester.runAsync(() async {
          try {
            await vm.operation;
          } catch (_) {
            /* The UI reports the error. */
          }
        });
        await tester.pumpAndSettle();
        expect(writes, 1);
        expect(reads, fail ? 0 : 1);
        if (fail) {
          expect(vm.state.records.single.id, '1');
          expect(find.textContaining('Gagal mengarsipkan'), findsOneWidget);
        } else {
          expect(vm.state.records, isEmpty);
          final cached = await tester.runAsync(repo.cached);
          expect(cached!.records, isEmpty);
          expect(find.textContaining('berhasil diarsipkan'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  test('archive ignores completion after ViewModel disposal', () async {
    final pending = Completer<void>();
    final api = apiFor((_) async {
      await pending.future;
      return reply({'data': {}});
    });
    addTearDown(api.close);
    final repo = InventoryRepository(
      api,
      Completer<InventoryCache>().future,
      userId: '1',
    );
    final vm = ConnectedInventoryViewModel(repo, autoLoad: false);
    final result = vm.deactivateItem('1');
    vm.dispose();
    pending.complete();
    await result;
  });
}
