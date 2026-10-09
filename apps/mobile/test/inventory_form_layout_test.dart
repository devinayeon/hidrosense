import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/repositories/inventory_repository.dart';
import 'package:hidrosense_mobile/data/models/inventory_record.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/data/services/inventory_cache.dart';
import 'package:hidrosense_mobile/viewmodels/connected_inventory_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/inventory_draft.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/views/pages/add_form_inventaris_page.dart';
import 'package:hidrosense_mobile/views/theme/app_theme.dart';
import 'package:hidrosense_mobile/views/widgets/row_button.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'inventory_save_widget_test.dart' show user, response, drain;
import 'inventory_repository_test.dart' show master;
import 'support/remediation_capture.dart';

void main() {
  setUpAll(loadCaptureFonts);
  for (final dark in [false, true]) {
    testWidgets(
      'inventory form small screen, text 2x, ${dark ? 'dark' : 'light'} theme, selectors, validation and pending states',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 568));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final pending = Completer<http.Response>();
        final api = ApiClient(
          MockClient((_) => pending.future),
          baseUri: Uri.parse('https://test.example/api/v1'),
        )..setTokens(accessToken: 'a', refreshToken: 'r');
        addTearDown(api.close);
        final vm = ConnectedInventoryViewModel(
          InventoryRepository(
            api,
            Completer<InventoryCache>().future,
            userId: '1',
          ),
          autoLoad: false,
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(api),
              connectedInventoryProvider.overrideWith((_) => vm),
              sessionProvider.overrideWith(
                (_) => SessionViewModel(
                  api,
                  initialState: const SessionState(user: user),
                ),
              ),
            ],
            child: MaterialApp(
              theme: dark
                  ? ThemeData.dark(useMaterial3: true)
                  : AppTheme.lightTheme,
              builder: (_, child) => RepaintBoundary(
                key: const ValueKey('remediation-capture'),
                child: MediaQuery(
                  data: const MediaQueryData(
                    size: Size(320, 568),
                    textScaler: TextScaler.linear(2),
                  ),
                  child: child!,
                ),
              ),
              home: const AddFormInventarisPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byType(RowButton)).height,
          greaterThanOrEqualTo(44),
        );
        await captureRemediation(
          tester,
          'inventory-${dark ? 'dark' : 'light'}-large-text',
        );
        await tester.ensureVisible(find.text('Pilih Kategori Barang'));
        await tester.tap(find.text('Pilih Kategori Barang'));
        await tester.pumpAndSettle();
        expect(find.text('Benih'), findsOneWidget);
        await tester.tap(find.text('Benih'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Satuan').last);
        await tester.tap(find.text('Satuan').last);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Pcs'),
          100,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text('Pcs'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(TextField).first);
        await tester.tap(find.byType(TextField).first);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.text('Pilih Kategori Barang'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Pilih Kategori Barang'), findsNothing);
        await tester.tap(find.text('Simpan Barang'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.text('Isi nama barang, maksimal 100 karakter.'),
        );
        expect(find.byType(SnackBar), findsNothing);
        await captureRemediation(
          tester,
          'inventory-${dark ? 'dark' : 'light'}-validation',
        );
        await tester.enterText(find.byType(TextField).first, 'Benih');
        await tester.tap(find.text('Simpan Barang'));
        await tester.pump();
        expect(find.text('Menyimpan...'), findsOneWidget);
        expect(
          tester.widget<PopScope>(find.byType(PopScope).first).canPop,
          false,
        );
        await captureRemediation(
          tester,
          'inventory-${dark ? 'dark' : 'light'}-saving',
        );
        pending.complete(
          response({
            'error': {'code': 'DOWN', 'message': 'Layanan belum tersedia'},
          }, status: 503),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.textContaining('Layanan belum tersedia'),
        );
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        expect(find.textContaining('Isian dipertahankan'), findsOneWidget);
        await captureRemediation(
          tester,
          'inventory-${dark ? 'dark' : 'light'}-retry',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('anonymous direct form builds only access guard', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AddFormInventarisPage())),
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Anda tidak memiliki akses inventaris.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mismatched form offers resume without exposing editable unrelated fields',
    (tester) async {
      final api = ApiClient(
        MockClient((_) async => throw StateError('No requests expected')),
        baseUri: Uri.parse('https://test.example/api/v1'),
      );
      addTearDown(api.close);
      const pending = InventoryDraft(
        id: '1',
        name: 'Pending edit',
        categoryId: '1',
        unit: 'kg',
        minimum: '',
        initialStock: '',
      );
      final vm = ConnectedInventoryViewModel(
        InventoryRepository(
          api,
          Completer<InventoryCache>().future,
          userId: '1',
        ),
        autoLoad: false,
        commands: {(api.serverOrigin, '1'): InventorySaveCommand(pending)},
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectedInventoryProvider.overrideWith((_) => vm),
            apiClientProvider.overrideWithValue(api),
            sessionProvider.overrideWith(
              (_) => SessionViewModel(
                api,
                initialState: const SessionState(user: user),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: AddFormInventarisPage(
              initialRecord: InventoryRecord.fromJson(master('2')),
            ),
          ),
        ),
      );
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Lanjutkan penyimpanan sebelumnya'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Pending edit',
      );
      expect(find.text('Edit Barang'), findsOneWidget);
      expect(tester.widget<PopScope>(find.byType(PopScope).first).canPop, true);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'finish without rejected stock closes form and refreshes once without POST',
    (tester) async {
      sqfliteFfiInit();
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
      var reads = 0;
      final api = ApiClient(
        MockClient((r) async {
          expect(r.method, 'GET');
          reads++;
          return response({
            'data': [],
            'meta': {'page': 1, 'limit': 20, 'total': 0, 'total_pages': 0},
          });
        }),
        baseUri: Uri.parse('https://test.example/api/v1'),
      )..setTokens(accessToken: 'a', refreshToken: 'r');
      addTearDown(api.close);
      const pending = InventoryDraft(
        name: 'Pending create',
        categoryId: '1',
        unit: 'kg',
        minimum: '',
        initialStock: '10',
      );
      final command = InventorySaveCommand(pending)
        ..item = InventoryRecord.fromJson(master('1'))
        ..canFinishWithoutStock = true;
      final vm = ConnectedInventoryViewModel(
        InventoryRepository(api, Future.value(cache), userId: '1'),
        autoLoad: false,
        commands: {(api.serverOrigin, '1'): command},
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectedInventoryProvider.overrideWith((_) => vm),
            apiClientProvider.overrideWithValue(api),
            sessionProvider.overrideWith(
              (_) => SessionViewModel(
                api,
                initialState: const SessionState(user: user),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Builder(
              builder: (ctx) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push(
                    ctx,
                    MaterialPageRoute<void>(
                      builder: (_) => const AddFormInventarisPage(),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Selesai tanpa saldo awal'));
      await drain(
        tester,
        () => find.byType(AddFormInventarisPage).evaluate().isEmpty,
      );
      expect(reads, 1);
      expect(find.text('Barang tersimpan tanpa saldo awal.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
