import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/inventory_record.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/data/services/inventory_cache.dart';
import 'package:hidrosense_mobile/data/repositories/inventory_repository.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/connected_inventory_viewmodel.dart';
import 'package:hidrosense_mobile/views/pages/add_form_inventaris_page.dart';
import 'package:hidrosense_mobile/views/theme/app_theme.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Map<String, dynamic> master(
  String id, {
  String name = 'Barang',
  String unit = 'Pcs',
  String? minimum,
}) => {
  'id_inventaris': id,
  'public_id': null,
  'version': null,
  'id_jenis_inventaris': '1',
  'id_obat': null,
  'nama_barang': name,
  'saldo': '0',
  'di_bawah_minimum': minimum != null,
  'satuan': unit,
  'stok_minimum': minimum,
  'status_aktif': 1,
  'nama_jenis': 'Benih',
  'nama_obat': null,
};
const user = SessionUser(
  id: '1',
  name: 'Petani',
  username: 'p',
  role: 'petani',
  permissions: ['inventaris:read', 'inventaris:write'],
);
http.Response response(Object body, {int status = 200}) =>
    http.Response(jsonEncode(body), status);
Future<void> drain(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 600; i++) {
    await tester.pump(const Duration(milliseconds: 25));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    if (done()) {
      await tester.pump();
      return;
    }
  }
  throw StateError('Trace did not complete');
}

void main() {
  sqfliteFfiInit();
  for (final mode in [
    'without_stock',
    'with_stock',
    'with_stock_100',
    'edit',
  ]) {
    final stock = mode.startsWith('with_stock');
    final edit = mode == 'edit';
    testWidgets('request count mode=$mode', (tester) async {
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
      final count = mode.endsWith('100') ? 100 : 10;
      final rows = List.generate(count, (i) => master((i + 1).toString()));
      final trace = <String>[];
      final api = ApiClient(
        MockClient((r) async {
          trace.add('${r.method} ${r.url.path}');
          await Future<void>.delayed(const Duration(milliseconds: 25));
          final path = r.url.path;
          if (r.method == 'PATCH') {
            final id = path.split('/').last;
            final body = jsonDecode(r.body) as Map;
            final index = rows.indexWhere((row) => row['id_inventaris'] == id);
            rows[index] = {...rows[index], ...body};
            return response({'data': rows[index]});
          }
          if (r.method == 'POST' && path.endsWith('/inventaris')) {
            final body = jsonDecode(r.body) as Map;
            final row = master(
              (rows.length + 1).toString(),
              name: body['nama_barang'] as String,
              unit: body['satuan'] as String,
              minimum: body['stok_minimum'] as String?,
            );
            rows.add(row);
            return response({'data': row}, status: 201);
          }
          if (r.method == 'POST' && path.endsWith('/stok')) {
            rows.last['saldo'] = '10';
            return response({
              'data': {
                'id_stok': '1',
                'id_user': '1',
                'tanggal_stok': '2026-10-09T00:00:00Z',
                'jenis_stok': 'masuk',
                'details': [
                  {
                    'id_detail_stok': '1',
                    'id_inventaris': '11',
                    'jumlah': '10',
                    'satuan': 'Pcs',
                  },
                ],
              },
            }, status: 201);
          }
          final page = int.parse(r.url.queryParameters['page']!);
          return response({
            'data': rows.skip((page - 1) * 20).take(20).toList(),
            'meta': {
              'page': page,
              'limit': 20,
              'total': rows.length,
              'total_pages': (rows.length / 20).ceil(),
            },
          });
        }),
        baseUri: Uri.parse('https://trace.test/api/v1'),
      )..setTokens(accessToken: 'a', refreshToken: 'r');
      addTearDown(api.close);
      final repo = InventoryRepository(api, Future.value(cache), userId: '1');
      final vm = ConnectedInventoryViewModel(
        repo,
        autoLoad: false,
        initialState: ConnectedInventoryState(
          records: rows
              .map((r) => InventoryRecord.fromJson({...r, 'saldo': '0'}))
              .toList(),
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            inventoryCacheProvider.overrideWithValue(Future.value(cache)),
            sessionProvider.overrideWith(
              (_) => SessionViewModel(
                api,
                initialState: const SessionState(user: user),
              ),
            ),
            connectedInventoryProvider.overrideWith((_) => vm),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => AddFormInventarisPage(
                        initialRecord: edit
                            ? InventoryRecord.fromJson({
                                ...rows.first,
                                'saldo': '0',
                              })
                            : null,
                      ),
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
      await tester.enterText(find.byType(TextField).at(0), 'Trace baru');
      if (stock) await tester.enterText(find.byType(TextField).at(1), '10');
      await tester.tap(find.text(edit ? 'Simpan Perubahan' : 'Simpan Barang'));
      await drain(
        tester,
        () => find.byType(AddFormInventarisPage).evaluate().isEmpty,
      );
      final lists = trace.where((r) => r == 'GET /api/v1/inventaris').length;
      final balances = trace.where((r) => r.endsWith('/saldo')).length;
      debugPrint(
        jsonEncode({
          'scenario': mode,
          'catalog_before': count,
          'catalog_after': rows.length,
          'requests': trace.length,
          'list_gets': lists,
          'balance_gets': balances,
          'posts': trace.where((r) => r.startsWith('POST ')).length,
          'trace': trace,
        }),
      );
      expect(trace.length, (stock ? 2 : 1) + (rows.length / 20).ceil());
      expect(lists, (rows.length / 20).ceil());
      expect(balances, 0);
      expect(rows.length, edit ? count : count + 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets(
    'empty name displays one inline error without requests or SnackBars',
    (tester) async {
      final api = ApiClient(
        MockClient((_) async => throw StateError('No requests expected')),
        baseUri: Uri.parse('https://trace.test/api/v1'),
      );
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
            sessionProvider.overrideWith(
              (_) => SessionViewModel(
                api,
                initialState: const SessionState(user: user),
              ),
            ),
            connectedInventoryProvider.overrideWith((_) => vm),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const AddFormInventarisPage(),
          ),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Simpan Barang'));
        await tester.pump();
      }
      expect(
        find.text('Isi nama barang, maksimal 100 karakter.'),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('two taps before rebuild submit once and back is blocked', (
    tester,
  ) async {
    var posts = 0;
    final pending = Completer<http.Response>();
    final api = ApiClient(
      MockClient((r) {
        posts++;
        return pending.future;
      }),
      baseUri: Uri.parse('https://trace.test/api/v1'),
    )..setTokens(accessToken: 'a', refreshToken: 'r');
    addTearDown(api.close);
    final vm = ConnectedInventoryViewModel(
      InventoryRepository(api, Completer<InventoryCache>().future, userId: '1'),
      autoLoad: false,
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
          inventoryCacheProvider.overrideWithValue(
            Completer<InventoryCache>().future,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AddFormInventarisPage(),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'Double tap');
    await tester.tap(find.text('Simpan Barang'));
    await tester.tap(find.text('Simpan Barang'));
    await tester.pump();
    expect(posts, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(
      response({
        'error': {'code': 'TRACE', 'message': 'Probe stopped'},
      }, status: 503),
    );
    await tester.pump();
  });
}
