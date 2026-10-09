import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/repositories/inventory_repository.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/data/services/inventory_cache.dart';
import 'package:hidrosense_mobile/viewmodels/connected_inventory_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/inventory_draft.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'inventory_repository_test.dart' show master, reply;

const draft = InventoryDraft(
  name: 'Benih',
  categoryId: '1',
  unit: 'kg',
  minimum: '1',
  initialStock: '10',
);
final stock = {
  'id_stok': '1',
  'id_user': '1',
  'tanggal_stok': '2026-10-09T00:00:00Z',
  'jenis_stok': 'masuk',
  'details': [
    {
      'id_detail_stok': '1',
      'id_inventaris': '1',
      'jumlah': '10',
      'satuan': 'kg',
    },
  ],
};

Future<(ApiClient, InventoryCache, ConnectedInventoryViewModel)> setup(
  Future<http.Response> Function(http.Request) handler, {
  Map<(String, String), InventorySaveCommand>? commands,
  bool failCache = false,
}) async {
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: InventoryCache.createSchema,
    ),
  );
  final cache = InventoryCache(db);
  final api = ApiClient(
    MockClient(handler),
    baseUri: Uri.parse('https://test.example/api/v1'),
  )..setTokens(accessToken: 'a', refreshToken: 'r');
  final repo = InventoryRepository(api, Future.value(cache), userId: '1');
  if (failCache) await cache.close();
  final vm = ConnectedInventoryViewModel(
    repo,
    autoLoad: false,
    commands: commands,
  );
  addTearDown(() async {
    if (vm.mounted) vm.dispose();
    api.close();
    if (!failCache) await cache.close();
  });
  return (api, cache, vm);
}

http.Response list() => reply(200, {
  'data': [master('1')],
  'meta': {'page': 1, 'limit': 20, 'total': 1, 'total_pages': 1},
});

void main() {
  sqfliteFfiInit();
  for (final stage in ['create', 'stock', 'edit']) {
    test(
      'lost $stage receipt replays same key/body and never creates a second item',
      () async {
        final seen = <String, List<http.Request>>{};
        var fail = true;
        final (_, _, vm) = await setup((r) async {
          final kind = r.method == 'PATCH'
              ? 'edit'
              : r.url.path.endsWith('/stok')
              ? 'stock'
              : r.method == 'POST'
              ? 'create'
              : 'list';
          (seen[kind] ??= []).add(r);
          if (kind == stage && fail) {
            fail = false;
            throw http.ClientException('Lost receipt');
          }
          return kind == 'list'
              ? list()
              : reply(201, {'data': kind == 'stock' ? stock : master('1')});
        });
        final input = stage == 'edit'
            ? const InventoryDraft(
                id: '1',
                name: 'Benih',
                categoryId: '1',
                unit: 'kg',
                minimum: '1',
                initialStock: '',
              )
            : draft;
        await expectLater(
          vm.saveItem(input),
          throwsA(isA<http.ClientException>()),
        );
        expect(vm.state.pendingDraft, same(input));
        expect(vm.state.canFinishWithoutStock, false);
        expect(await vm.saveItem(input), null);
        expect(vm.state.pendingDraft, null);
        final retries = seen[stage]!;
        expect(retries.length, 2);
        expect(
          retries.first.headers['Idempotency-Key'],
          retries.last.headers['Idempotency-Key'],
        );
        expect(retries.first.body, retries.last.body);
        expect(seen['list']!.length, 1);
        if (stage == 'stock') expect(seen['create']!.length, 1);
      },
    );
  }

  for (final failCache in [false, true]) {
    test(
      'committed save plus ${failCache ? 'cache' : 'refresh'} failure returns warning; retry refresh sends no mutations',
      () async {
        var posts = 0, gets = 0, fail = true;
        final (_, _, vm) = await setup((r) async {
          if (r.method == 'POST') {
            posts++;
            return reply(201, {
              'data': r.url.path.endsWith('/stok') ? stock : master('1'),
            });
          }
          gets++;
          if (fail && !failCache) {
            return reply(503, {
              'error': {'code': 'DOWN', 'message': 'Belum siap'},
            });
          }
          return list();
        }, failCache: failCache);
        expect(await vm.saveItem(draft), isNotNull);
        expect(vm.state.pendingDraft, null);
        expect(vm.state.saving, false);
        fail = false;
        await vm.refresh();
        expect(posts, 2);
        expect(gets, 2);
      },
    );
  }

  test(
    'known stock rejection permits finish without stock, while uncertain result cannot be skipped',
    () async {
      var posts = 0, lists = 0;
      final (_, _, vm) = await setup((r) async {
        if (r.method == 'GET') {
          lists++;
          return list();
        }
        posts++;
        return r.url.path.endsWith('/stok')
            ? reply(422, {
                'error': {'code': 'UNIT_MISMATCH', 'message': 'Satuan berubah'},
              })
            : reply(201, {'data': master('1')});
      });
      await expectLater(vm.saveItem(draft), throwsA(isA<ApiException>()));
      expect(vm.state.canFinishWithoutStock, true);
      expect(await vm.finishWithoutStock(), null);
      expect(vm.state.pendingDraft, null);
      expect(posts, 2);
      expect(lists, 1);
    },
  );

  test(
    'unknown stock result followed by 429 remains uncertain and cannot be skipped',
    () async {
      var attempts = 0;
      final (_, _, vm) = await setup((r) async {
        if (r.url.path.endsWith('/stok')) {
          if (++attempts == 1) throw http.ClientException('Receipt lost');
          return reply(429, {
            'error': {'code': 'RATE_LIMITED', 'message': 'Tunggu'},
          });
        }
        return reply(201, {'data': master('1')});
      });
      await expectLater(
        vm.saveItem(draft),
        throwsA(isA<http.ClientException>()),
      );
      await expectLater(vm.saveItem(draft), throwsA(isA<ApiException>()));
      expect(vm.state.canFinishWithoutStock, false);
      await expectLater(vm.finishWithoutStock(), throwsStateError);
    },
  );

  test(
    'definite create rejection allows corrections with a new UUID',
    () async {
      final keys = <String>[];
      final (_, _, vm) = await setup((r) async {
        if (r.method == 'GET') return list();
        keys.add(r.headers['Idempotency-Key']!);
        return keys.length == 1
            ? reply(422, {
                'error': {
                  'code': 'JENIS_NOT_FOUND',
                  'message': 'Kategori tidak aktif',
                },
              })
            : reply(201, {'data': master('1')});
      });
      const input = InventoryDraft(
        name: 'X',
        categoryId: '1',
        unit: 'kg',
        minimum: '',
        initialStock: '',
      );
      await expectLater(vm.saveItem(input), throwsA(isA<ApiException>()));
      expect(vm.state.pendingDraft, null);
      await vm.saveItem(
        const InventoryDraft(
          name: 'Y',
          categoryId: '2',
          unit: 'kg',
          minimum: '',
          initialStock: '',
        ),
      );
      expect(keys[0], isNot(keys[1]));
    },
  );

  test(
    'session expiry/disposal retains receipt for same account and hides it from other accounts/servers',
    () async {
      final commands = <(String, String), InventorySaveCommand>{};
      var stockAttempts = 0;
      final keys = <String>[];
      final (api, cache, vm) = await setup((r) async {
        if (r.method == 'GET') return list();
        if (r.url.path.endsWith('/stok')) {
          keys.add(r.headers['Idempotency-Key']!);
          if (++stockAttempts == 1) {
            vmDispose?.call();
            throw http.ClientException('Session lost');
          }
          return reply(201, {'data': stock});
        }
        return reply(201, {'data': master('1')});
      }, commands: commands);
      vmDispose = vm.dispose;
      await vm.saveItem(draft);
      vmDispose = null;
      final other = ConnectedInventoryViewModel(
        InventoryRepository(api, Future.value(cache), userId: '2'),
        autoLoad: false,
        commands: commands,
      );
      expect(other.state.pendingDraft, null);
      other.dispose();
      final otherApi = ApiClient(
        MockClient((_) async => list()),
        baseUri: Uri.parse('https://other.example/api/v1'),
      );
      final otherServer = ConnectedInventoryViewModel(
        InventoryRepository(otherApi, Future.value(cache), userId: '1'),
        autoLoad: false,
        commands: commands,
      );
      expect(otherServer.state.pendingDraft, null);
      otherServer.dispose();
      otherApi.close();
      final resumed = ConnectedInventoryViewModel(
        InventoryRepository(api, Future.value(cache), userId: '1'),
        autoLoad: false,
        commands: commands,
      );
      expect(resumed.state.pendingDraft, same(draft));
      expect(await resumed.saveItem(draft), null);
      expect(keys, [keys.first, keys.first]);
      expect(commands, isEmpty);
      resumed.dispose();
    },
  );

  test('token refresh replays identical create UUID and payload', () async {
    final requests = <http.Request>[];
    final (_, _, vm) = await setup((r) async {
      if (r.url.path.endsWith('/auth/refresh')) {
        return reply(200, {
          'data': {'access_token': 'b', 'refresh_token': 's'},
        });
      }
      if (r.method == 'GET') return list();
      if (r.url.path.endsWith('/stok')) return reply(201, {'data': stock});
      requests.add(r);
      return requests.length == 1
          ? reply(401, {
              'error': {'code': 'TOKEN_EXPIRED', 'message': 'Expired'},
            })
          : reply(201, {'data': master('1')});
    });
    await vm.saveItem(draft);
    expect(requests.length, 2);
    expect(requests[0].body, requests[1].body);
    expect(
      requests[0].headers['Idempotency-Key'],
      requests[1].headers['Idempotency-Key'],
    );
    expect(requests[1].headers['Authorization'], 'Bearer b');
  });

  test('invalid decimal inputs issue no requests', () async {
    final (_, _, vm) = await setup(
      (_) async => throw StateError('No requests expected'),
    );
    for (final quantity in ['-1', '1.001', '10000000000', 'abc', '1e2']) {
      await expectLater(
        vm.saveItem(
          InventoryDraft(
            name: 'A',
            categoryId: '1',
            unit: 'kg',
            minimum: '',
            initialStock: quantity,
          ),
        ),
        throwsStateError,
      );
    }
  });

  test('stale disposed attempt cannot erase a newer uncertain retry', () async {
    final commands = <(String, String), InventorySaveCommand>{};
    final firstResponse = Completer<http.Response>();
    final keys = <String>[];
    var attempts = 0;
    final (api, cache, vm) = await setup((r) async {
      if (r.method == 'GET') return list();
      if (r.url.path.endsWith('/stok')) return reply(201, {'data': stock});
      keys.add(r.headers['Idempotency-Key']!);
      attempts++;
      if (attempts == 1) return firstResponse.future;
      if (attempts == 2) {
        throw http.ClientException('Committed retry receipt lost');
      }
      return reply(200, {'data': master('1')});
    }, commands: commands);
    final first = vm.saveItem(draft);
    await Future<void>.delayed(Duration.zero);
    vm.dispose();
    final resumed = ConnectedInventoryViewModel(
      InventoryRepository(api, Future.value(cache), userId: '1'),
      autoLoad: false,
      commands: commands,
    );
    await expectLater(
      resumed.saveItem(draft),
      throwsA(isA<http.ClientException>()),
    );
    firstResponse.complete(
      reply(422, {
        'error': {'code': 'STALE', 'message': 'Old attempt'},
      }),
    );
    await first;
    expect(resumed.state.pendingDraft, same(draft));
    expect(commands.length, 1);
    expect(await resumed.saveItem(draft), null);
    expect(keys, [keys.first, keys.first, keys.first]);
    resumed.dispose();
  });

  test(
    'session switch after committed HTTP response retains uncertain UUID',
    () async {
      late ApiClient activeApi;
      var attempts = 0;
      final keys = <String>[];
      final (api, _, vm) = await setup((r) async {
        if (r.method == 'GET') return list();
        if (r.url.path.endsWith('/stok')) return reply(201, {'data': stock});
        keys.add(r.headers['Idempotency-Key']!);
        if (++attempts == 1) activeApi.clearSession();
        return reply(201, {'data': master('1')});
      });
      activeApi = api;
      await expectLater(vm.saveItem(draft), throwsA(isA<ApiException>()));
      expect(vm.state.pendingDraft, same(draft));
      api.setTokens(accessToken: 'b', refreshToken: 's');
      expect(await vm.saveItem(draft), null);
      expect(keys[0], keys[1]);
    },
  );

  test(
    'final refresh waits for a read started before the write then reads again',
    () async {
      final oldList = Completer<http.Response>();
      var reads = 0;
      final (_, _, vm) = await setup((r) async {
        if (r.method == 'GET') return ++reads == 1 ? oldList.future : list();
        return reply(201, {
          'data': r.url.path.endsWith('/stok') ? stock : master('1'),
        });
      });
      final oldRefresh = vm.refresh();
      await Future<void>.delayed(Duration.zero);
      final save = vm.saveItem(draft);
      await Future<void>.delayed(Duration.zero);
      expect(reads, 1);
      oldList.complete(
        reply(200, {
          'data': [],
          'meta': {'page': 1, 'limit': 20, 'total': 0, 'total_pages': 0},
        }),
      );
      await oldRefresh;
      await save;
      expect(reads, 2);
      expect(vm.state.records.length, 1);
    },
  );
}

void Function()? vmDispose;
