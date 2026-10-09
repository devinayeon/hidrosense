import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/core/business_date.dart';
import 'package:hidrosense_mobile/data/repositories/nursery_repository.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/viewmodels/connected_nursery_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/sowing_draft.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> record({
  String id = '9223372036854775806',
  int count = 100,
  int age = 14,
}) => {
  'id_penyemaian': id,
  'id_user': '1',
  'tanggal_semai': '2026-09-16',
  'jumlah_benih': count,
  'sisa_benih': count,
  'status_penyemaian': 'aktif',
  'usia_hari': age,
  'siap_pindah': age >= 15,
  'keterangan': '',
  'stok_konsumsi': [
    {
      'id_inventaris': '9223372036854775805',
      'jumlah': '1.25',
      'satuan': 'gram',
    },
  ],
};
http.Response response(Object value, [int status = 200]) =>
    http.Response(jsonEncode(value), status);
Map<String, dynamic> page(
  List<Object> data, {
  int page = 1,
  int? total,
  int? pages,
}) => {
  'data': data,
  'meta': {
    'page': page,
    'total': total ?? data.length,
    'total_pages': pages ?? (data.isEmpty ? 0 : 1),
  },
};
ApiClient client(Future<http.Response> Function(http.Request) handler) =>
    ApiClient(
      MockClient(handler),
      baseUri: Uri.parse('https://nursery.test/api/v1'),
    )..setTokens(accessToken: 'access', refreshToken: 'refresh');
const create = SowingDraft(
  date: '2026-09-16',
  seedCount: 100,
  note: '',
  inventoryId: '9223372036854775805',
  amount: '1.25',
  unit: 'gram',
);
const edit = SowingDraft(
  id: '9223372036854775806',
  date: '2026-09-16',
  seedCount: 120,
  note: '',
);
const petani = SessionUser(
  id: '1',
  name: 'Petani',
  username: 'petani',
  role: 'petani',
  permissions: ['penyemaian:read', 'penyemaian:write'],
);

class TestSession extends SessionViewModel {
  TestSession(super.api)
    : super(initialState: const SessionState(user: petani));
  void switchTo(SessionUser? user) => state = SessionState(user: user);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'all pages retain the oldest ready batch and signed64 IDs/material mapping',
    () async {
      final visited = <String>[];
      final api = client((req) async {
        visited.add(req.url.queryParameters['page']!);
        expect(req.url.queryParameters['limit'], '50');
        return response(
          visited.length == 1
              ? page(
                  List.generate(50, (i) => record(id: '${i + 1}', age: 1)),
                  total: 51,
                  pages: 2,
                )
              : page([record(age: 15)], page: 2, total: 51, pages: 2),
        );
      });
      addTearDown(api.close);
      final records = await NurseryRepository(api).listSowings();
      expect(visited, ['1', '2']);
      expect(records.length, 51);
      expect(records.last.canTransfer, isTrue);
      expect(records.last.id, '9223372036854775806');
      expect(records.last.materials.single.inventoryId, '9223372036854775805');
      expect(records.last.materials.single.amount, '1.25');
    },
  );
  test(
    'duplicate IDs and changed pagination totals reject partial catalogs',
    () async {
      for (final duplicate in [true, false]) {
        var requests = 0;
        final api = client(
          (_) async => response(
            ++requests == 1
                ? page([record(id: '1')], total: 2, pages: 2)
                : page(
                    [record(id: duplicate ? '1' : '2')],
                    page: 2,
                    total: duplicate ? 2 : 3,
                    pages: 2,
                  ),
          ),
        );
        await expectLater(
          NurseryRepository(api).listSowings(),
          throwsFormatException,
        );
        api.close();
      }
    },
  );
  for (final draft in [create, edit]) {
    test(
      '${draft.id == null ? 'create' : 'edit'} retry preserves UUID/body, token refresh, and clears notes',
      () async {
        final keys = <String>[], bodies = <String>[];
        var authExpired = true, authRefresh = 0;
        final api = client((req) async {
          if (req.url.path.endsWith('/auth/refresh')) {
            authRefresh++;
            return response({
              'data': {
                'access_token': 'renewed',
                'refresh_token': 'new-refresh',
              },
            });
          }
          if (req.method != 'GET') {
            keys.add(req.headers['Idempotency-Key']!);
            bodies.add(req.body);
            if (keys.length == 1) throw TimeoutException('Commit receipt lost');
            if (authExpired) {
              authExpired = false;
              return response({
                'error': {'code': 'TOKEN_EXPIRED', 'message': 'Expired'},
              }, 401);
            }
            return response({
              'data': record(count: draft.seedCount),
            }, draft.id == null ? 201 : 200);
          }
          return response(page([record(count: draft.seedCount)]));
        });
        addTearDown(api.close);
        var inventoryRefresh = 0;
        final vm = ConnectedNurseryViewModel(
          NurseryRepository(api),
          autoLoad: false,
          refreshInventory: () async {
            inventoryRefresh++;
            return null;
          },
        );
        addTearDown(vm.dispose);
        await expectLater(
          vm.saveSowing(draft),
          throwsA(isA<TimeoutException>()),
        );
        expect(vm.state.pendingDraft, same(draft));
        final altered = SowingDraft(
          id: draft.id,
          date: draft.date,
          seedCount: 999,
          note: 'changed',
          inventoryId: create.inventoryId,
          amount: '9',
          unit: 'gram',
        );
        expect(await vm.saveSowing(altered), isNull);
        expect(keys.toSet().length, 1);
        expect(bodies.toSet().length, 1);
        expect(authRefresh, 1);
        final body = jsonDecode(bodies.last);
        expect(body['jumlah_benih'], draft.seedCount);
        if (draft.id != null) {
          expect(body['keterangan'], '');
          expect(body.containsKey('tanggal_semai'), isFalse);
        } else {
          expect(body['materials'][0]['jumlah'], '1.25');
          expect(body['materials'][0]['id_inventaris'], create.inventoryId);
        }
        expect(vm.state.records.single.seedCount, draft.seedCount);
        expect(vm.state.pendingDraft, isNull);
        expect(vm.state.saving, isFalse);
        expect(inventoryRefresh, draft.id == null ? 1 : 0);
      },
    );
  }
  test('committed save survives failed refresh without another POST', () async {
    var posts = 0;
    final api = client((req) async {
      if (req.method == 'POST') {
        posts++;
        return response({'data': record()}, 201);
      }
      return response({
        'error': {'message': 'Refresh unavailable'},
      }, 503);
    });
    addTearDown(api.close);
    final vm = ConnectedNurseryViewModel(
      NurseryRepository(api),
      autoLoad: false,
    );
    addTearDown(vm.dispose);
    expect(await vm.saveSowing(create), 'Refresh unavailable');
    expect(vm.state.records.single.id, record()['id_penyemaian']);
    expect(vm.state.pendingDraft, isNull);
    await vm.refresh();
    expect(posts, 1);
  });
  test(
    'double submit is blocked and a pre-write read cannot overwrite the receipt',
    () async {
      final initial = Completer<http.Response>(),
          posted = Completer<http.Response>();
      var reads = 0, writes = 0;
      final api = client((req) async {
        if (req.method == 'POST') {
          writes++;
          return posted.future;
        }
        return ++reads == 1 ? initial.future : response(page([record()]));
      });
      addTearDown(api.close);
      final vm = ConnectedNurseryViewModel(NurseryRepository(api));
      addTearDown(vm.dispose);
      final saved = vm.saveSowing(create);
      await vm.saveSowing(create);
      await Future<void>.delayed(Duration.zero);
      expect(writes, 1);
      posted.complete(response({'data': record()}, 201));
      initial.complete(response(page([])));
      await saved;
      expect(reads, 2);
      expect(vm.state.records.single.id, record()['id_penyemaian']);
    },
  );
  test(
    'disposed save receipt stays scoped to account and resumes without another write',
    () async {
      final posted = Completer<http.Response>();
      var writes = 0;
      final api = client((req) async {
        if (req.method == 'POST') {
          writes++;
          return posted.future;
        }
        return response(page([record()]));
      });
      addTearDown(api.close);
      final commands = <(String, String), SowingCommand>{};
      final vm = ConnectedNurseryViewModel(
        NurseryRepository(api),
        autoLoad: false,
        userId: '1',
        commands: commands,
      );
      final saving = vm.saveSowing(create);
      vm.dispose();
      posted.complete(response({'data': record()}, 201));
      await saving;
      final other = ConnectedNurseryViewModel(
        NurseryRepository(api),
        autoLoad: false,
        userId: '2',
        commands: commands,
      );
      expect(other.state.pendingDraft, isNull);
      other.dispose();
      final same = ConnectedNurseryViewModel(
        NurseryRepository(api),
        autoLoad: false,
        userId: '1',
        commands: commands,
      );
      expect(identical(same.state.pendingDraft, create), isTrue);
      await same.saveSowing(create);
      expect(writes, 1);
      expect(commands, isEmpty);
      same.dispose();
    },
  );
  test('422 rejection unlocks corrected payload with a new UUID', () async {
    final keys = <String>[];
    final api = client((req) async {
      if (req.method == 'POST') {
        keys.add(req.headers['Idempotency-Key']!);
        return keys.length == 1
            ? response({
                'error': {
                  'code': 'STOCK_INSUFFICIENT',
                  'message': 'Stock insufficient',
                },
              }, 422)
            : response({'data': record()}, 201);
      }
      return response(page([record()]));
    });
    addTearDown(api.close);
    final vm = ConnectedNurseryViewModel(
      NurseryRepository(api),
      autoLoad: false,
    );
    addTearDown(vm.dispose);
    await expectLater(vm.saveSowing(create), throwsA(isA<ApiException>()));
    expect(vm.state.pendingDraft, isNull);
    await vm.saveSowing(create);
    expect(keys.toSet().length, 2);
  });
  test(
    'Jakarta calendar and invalid drafts do not accept normalized dates or zero stock',
    () {
      expect(
        apiDate(jakartaToday(DateTime.parse('2026-09-30T17:00:00Z'))),
        '2026-10-01',
      );
      expect(
        untilJakartaMidnight(DateTime.parse('2026-09-30T16:59:59Z')),
        const Duration(seconds: 1),
      );
      for (final amount in ['', '0', '-1', '1.234', '10000000000', 'abc']) {
        expect(
          SowingDraft(
            date: create.date,
            seedCount: 100,
            note: '',
            inventoryId: '1',
            amount: amount,
            unit: 'gram',
          ).errors,
          contains('amount'),
        );
      }
      expect(
        const SowingDraft(
          date: '2026-02-30',
          seedCount: 0,
          note: '',
        ).errors.keys,
        containsAll(['date', 'count', 'seed', 'amount']),
      );
    },
  );
  testWidgets(
    'midnight/resume refresh readiness; session change disposes timer and state',
    (tester) async {
      var now = DateTime.parse('2026-09-30T16:59:59Z'), reads = 0;
      final api = client((_) async {
        reads++;
        return response(page([record(age: now.hour == 16 ? 14 : 15)]));
      });
      final session = TestSession(api);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          sessionProvider.overrideWith((ref) => session),
          nurseryClockProvider.overrideWithValue(() => now),
        ],
      );
      final sub = container.listen(connectedNurseryProvider, (_, _) {});
      await tester.pump();
      expect(
        container.read(connectedNurseryProvider).records.single.canTransfer,
        isFalse,
      );
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(
        container.read(connectedNurseryProvider).records.single.canTransfer,
        isTrue,
      );
      expect(reads, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(reads, 3);
      final old = container.read(connectedNurseryProvider.notifier);
      session.switchTo(null);
      await tester.pump();
      expect(old.mounted, isFalse);
      sub.close();
      container.dispose();
      await tester.pump(const Duration(days: 1));
      expect(reads, 3);
      api.close();
    },
  );
}
