import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/table_record.dart';
import 'package:hidrosense_mobile/data/repositories/damage_repository.dart';
import 'package:hidrosense_mobile/data/repositories/inventory_repository.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/data/services/inventory_cache.dart';
import 'package:hidrosense_mobile/viewmodels/connected_inventory_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/views/components/inventaris_body.dart';
import 'package:hidrosense_mobile/views/pages/info_meja_page.dart';
import 'package:hidrosense_mobile/views/theme/app_theme.dart';
import 'package:hidrosense_mobile/views/widgets/custom_back_button.dart';
import 'package:http/io_client.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _RealHttpOverrides extends HttpOverrides {}

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsWidgets);
}

void main() {
  testWidgets(
    'real backend persists damage and inventory archive through UI',
    (tester) async {
      final api = await tester.runAsync(() async {
        final server = await Process.start('node', [
          '--input-type=module',
          '--import',
          'tsx',
          '-e',
          r'''
import { fixture } from './test-support/fixture.js';
const cleanups = [];
const f = await fixture({after: (fn) => cleanups.push(fn)});
await f.db.executeMultiple(`
INSERT INTO penyemaian(id_user,tanggal_semai,jumlah_benih,status_penyemaian) VALUES(1,'2026-09-01',500,'aktif');
INSERT INTO meja_tanam(kode_meja,jumlah_lubang,status_meja) VALUES('M-01',250,'tersedia');
INSERT INTO pemindahan(id_penyemaian,id_meja,tanggal_pemindahan,jumlah_tanaman) VALUES(1,1,'2026-09-16',200);
`);
const url = await f.app.listen({host: '127.0.0.1', port: 0});
console.log(JSON.stringify({url}));
process.on('SIGTERM', async () => { for (const cleanup of cleanups.reverse()) await cleanup(); process.exit(0); });
''',
        ], workingDirectory: '../backend');
        final errors = <String>[];
        final stderr = server.stderr.transform(utf8.decoder).listen(errors.add);
        addTearDown(() async {
          server.kill();
          await server.exitCode.timeout(const Duration(seconds: 10));
          await stderr.cancel();
        });
        final line = await server.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .first
            .timeout(
              const Duration(seconds: 20),
              onTimeout: () => throw StateError(errors.join()),
            );
        final url = (jsonDecode(line) as Map<String, dynamic>)['url'] as String;
        final client = _RealHttpOverrides().createHttpClient(null);
        return ApiClient(
          IOClient(client),
          baseUri: Uri.parse('$url/api/v1'),
          allowInsecureLocalhost: true,
        );
      });
      expect(api, isNotNull);
      addTearDown(api!.close);
      final user = await tester.runAsync(
        () => api.login('petani', 'Fixture password 2026!'),
      );
      final tableResponse = await tester.runAsync(
        () => api.get('meja-tanam/1'),
      );
      final table = TableRecord.fromJson(
        tableResponse!['data'] as Map<String, dynamic>,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            sessionProvider.overrideWith(
              (_) =>
                  SessionViewModel(api, initialState: SessionState(user: user)),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: InfoMejaPage(tableRecord: table),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Batch & Laporan Kerusakan'));
      await tester.tap(find.text('Batch & Laporan Kerusakan'));
      await waitFor(tester, find.text('Catat Kerusakan'));
      await tester.ensureVisible(find.text('Catat Kerusakan'));
      await tester.tap(find.text('Catat Kerusakan'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '5');
      await tester.enterText(
        find.byType(TextFormField).last,
        'Bukti persistensi dari UI',
      );
      await tester.ensureVisible(find.textContaining('Tanggal kejadian:'));
      await tester.tap(find.textContaining('Tanggal kejadian:'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '09/20/2026');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Simpan Laporan Kerusakan'));
      await tester.tap(find.text('Simpan Laporan Kerusakan'));
      await waitFor(tester, find.text('Laporan kerusakan berhasil disimpan.'));
      await tester.runAsync(() async {
        final inspector = ApiClient(
          IOClient(_RealHttpOverrides().createHttpClient(null)),
          baseUri: api.baseUri,
          allowInsecureLocalhost: true,
        );
        try {
          await inspector.login('petani', 'Fixture password 2026!');
          final repository = DamageRepository(inspector);
          final persisted = await repository.listDamages('1');
          expect(persisted.single.note, 'Bukti persistensi dari UI');
          expect(persisted.single.plantCount, 5);
          expect(
            (await repository.listTransfers('1')).single.activePlants,
            195,
          );
          final capacity = await inspector.get('meja-tanam/1');
          expect((capacity['data'] as Map)['kapasitas_tersedia'], 55);
        } finally {
          inspector.close();
        }
      });
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CustomBackButton));
      await tester.pumpAndSettle();
      expect(find.textContaining('195 / 250'), findsOneWidget);
      await tester.ensureVisible(find.text('Batch & Laporan Kerusakan'));
      await tester.tap(find.text('Batch & Laporan Kerusakan'));
      await waitFor(tester, find.textContaining('Bukti persistensi dari UI'));
      expect(find.textContaining('Bukti persistensi dari UI'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      sqfliteFfiInit();
      final cache = await tester.runAsync(
        () async => InventoryCache(
          await databaseFactoryFfi.openDatabase(
            inMemoryDatabasePath,
            options: OpenDatabaseOptions(
              version: 1,
              onCreate: InventoryCache.createSchema,
            ),
          ),
        ),
      );
      addTearDown(cache!.close);
      final inventoryApi = (await tester.runAsync(
        () async => ApiClient(
          IOClient(_RealHttpOverrides().createHttpClient(null)),
          baseUri: api.baseUri,
          allowInsecureLocalhost: true,
        ),
      ))!;
      addTearDown(inventoryApi.close);
      final inventoryUser = await tester.runAsync(
        () => inventoryApi.login('petani', 'Fixture password 2026!'),
      );
      final repo = (await tester.runAsync(
        () async => InventoryRepository(
          inventoryApi,
          Future.value(cache),
          userId: inventoryUser!.id,
        ),
      ))!;
      final item = await tester.runAsync(() async {
        final category = await inventoryApi.post(
          'jenis-inventaris',
          body: {'nama_jenis': 'Benih'},
        );
        return repo.createItem(
          categoryId:
              (category['data'] as Map)['id_jenis_inventaris'] as String,
          name: 'Bukti arsip nyata',
          unit: 'gram',
        );
      });
      final inventoryVm = ConnectedInventoryViewModel(
        repo,
        autoLoad: false,
        initialState: ConnectedInventoryState(records: [item!]),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(inventoryApi),
            sessionProvider.overrideWith(
              (_) => SessionViewModel(
                inventoryApi,
                initialState: SessionState(user: inventoryUser),
              ),
            ),
            connectedInventoryProvider.overrideWith((_) => inventoryVm),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: InventarisBody()),
          ),
        ),
      );
      await tester.tap(find.text('Bukti arsip nyata'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Arsipkan'));
      await tester.tap(find.text('Arsipkan'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Arsipkan'));
      await waitFor(tester, find.textContaining('berhasil diarsipkan'));
      expect(inventoryVm.state.records, isEmpty);
      final cached = await tester.runAsync(repo.cached);
      expect(cached!.records, isEmpty);
      await tester.runAsync(() async {
        final inspector = ApiClient(
          IOClient(_RealHttpOverrides().createHttpClient(null)),
          baseUri: api.baseUri,
          allowInsecureLocalhost: true,
        );
        try {
          await inspector.login('petani', 'Fixture password 2026!');
          final persisted = await inspector.get('inventaris/${item.id}');
          expect((persisted['data'] as Map)['status_aktif'], 0);
        } finally {
          inspector.close();
        }
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      inventoryApi.close();
      api.close();
      await tester.pump();
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
