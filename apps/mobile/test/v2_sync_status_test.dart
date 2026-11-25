import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/repositories/sync_status_repository.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/data/services/local_kv_store.dart';
import 'package:hidrosense_mobile/viewmodels/v2_sync_queue.dart';
import 'package:hidrosense_mobile/viewmodels/v2_sync_replayer.dart';
import 'package:hidrosense_mobile/viewmodels/v2_sync_status.dart';
import 'package:hidrosense_mobile/views/v2/components/v2_sinkron_data.dart';
import 'package:hidrosense_mobile/views/v2/pages/v2_sinkron_page.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Permintaan pemilik (2026-11-23): jam "Terakhir sinkron" muncul sesuai klik
// sinkron, tetapi setelah keluar dari menu kembali ke 09.40.

final _serverTime = DateTime.utc(2026, 11, 23, 10, 38);

Future<LocalKvStore> _store() async => LocalKvStore(
  await databaseFactoryFfiNoIsolate.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      singleInstance: false,
      onCreate: LocalKvStore.createSchema,
    ),
  ),
);

/// Layanan sinkron palsu: menyimpan jam terakhir per `device_id`.
class _FakeServer {
  _FakeServer({this.online = true});

  bool online;
  final Map<String, DateTime> stored = {};
  int posts = 0;

  http.Response _reply(DateTime? time) => http.Response(
    jsonEncode({
      'data': {'last_synced_at': time?.toIso8601String()},
    }),
    200,
  );

  Future<http.Response> handle(http.Request request) async {
    if (!online) throw http.ClientException('offline');
    if (request.url.path.endsWith('/sync/status')) {
      if (request.method == 'GET') {
        return _reply(stored[request.url.queryParameters['device_id']]);
      }
      final device = (jsonDecode(request.body) as Map)['device_id'] as String;
      posts++;
      stored[device] = _serverTime;
      return _reply(_serverTime);
    }
    return http.Response('{"data":{}}', 200);
  }
}

ApiClient _api(_FakeServer server) => ApiClient(
  MockClient(server.handle),
  baseUri: Uri.parse('https://example.test/api/v1'),
)..setTokens(accessToken: 'access', refreshToken: 'refresh');

SyncStatusRepository _repo(
  ApiClient api,
  LocalKvStore store, {
  String userId = '1',
  DateTime Function()? clock,
}) =>
    SyncStatusRepository(api, () async => store, userId: userId, clock: clock);

void main() {
  setUpAll(sqfliteFfiInit);

  group('SyncStatusRepository', () {
    test(
      'jam sinkron bertahan setelah keluar dari menu (repository baru)',
      () async {
        final store = await _store();
        final server = _FakeServer();
        final api = _api(server);
        addTearDown(api.close);

        final stamped = await _repo(api, store).markSynced();
        expect(stamped, _serverTime);

        // Keluar dari menu = halaman dan controller dibuang. Yang dibuat ulang
        // hanyalah objek di memori; penyimpanan HP dan server tetap.
        final reopened = _repo(api, store);
        expect(await reopened.readLocal(), _serverTime);
        expect(await reopened.refresh(), _serverTime);
      },
    );

    test('jam tersimpan di HP walau server tidak terjangkau', () async {
      final store = await _store();
      final server = _FakeServer();
      final api = _api(server);
      addTearDown(api.close);
      await _repo(api, store).markSynced();

      server.online = false;
      expect(await _repo(api, store).refresh(), _serverTime);
    });

    test('jam server yang lebih baru menggantikan jam HP', () async {
      final store = await _store();
      final server = _FakeServer();
      final api = _api(server);
      addTearDown(api.close);
      final repo = _repo(api, store);
      final device = await repo.deviceId();
      server.stored[device] = _serverTime.add(const Duration(hours: 2));

      expect(await repo.refresh(), _serverTime.add(const Duration(hours: 2)));
      expect(
        await _repo(api, store).readLocal(),
        _serverTime.add(const Duration(hours: 2)),
      );
    });

    test('belum pernah sinkron: tidak ada jam yang dikarang', () async {
      final store = await _store();
      final api = _api(_FakeServer());
      addTearDown(api.close);
      expect(await _repo(api, store).readLocal(), isNull);
      expect(await _repo(api, store).refresh(), isNull);
    });

    test(
      'tanpa bukti sambungan sinkron tidak dicatat; dengan data terkirim dicatat',
      () async {
        final store = await _store();
        final server = _FakeServer(online: false);
        final api = _api(server);
        addTearDown(api.close);
        final local = DateTime.utc(2026, 11, 23, 12, 5);

        await expectLater(
          _repo(api, store, clock: () => local).markSynced(),
          throwsA(isA<Exception>()),
        );
        expect(await _repo(api, store).readLocal(), isNull);

        expect(
          await _repo(
            api,
            store,
            clock: () => local,
          ).markSynced(trustLocal: true),
          local,
        );
        expect(await _repo(api, store).readLocal(), local);
      },
    );

    test(
      'pengenal perangkat dibuat sekali dan akun lain tidak berbagi jam',
      () async {
        final store = await _store();
        final api = _api(_FakeServer());
        addTearDown(api.close);
        final first = await _repo(api, store).deviceId();
        expect(await _repo(api, store).deviceId(), first);
        expect(first, matches(RegExp(r'^[0-9a-f-]{36}$')));

        await _repo(api, store).markSynced();
        expect(await _repo(api, store, userId: '2').readLocal(), isNull);
        expect(await _repo(api, store, userId: '2').deviceId(), isNot(first));
      },
    );
  });

  group('v2SyncRound', () {
    Future<DateTime> ok({bool trustLocal = false}) async => _serverTime;
    Future<DateTime> fail({bool trustLocal = false}) async =>
        throw http.ClientException('offline');

    test('antrean selesai: putaran membawa jam yang dicatat server', () async {
      final run = await v2SyncRound(
        run: () async => const V2SyncRun(sent: 2, total: 2),
        markSynced: ok,
      );
      expect(run.remaining, 0);
      expect(run.syncedAt, _serverTime);
    });

    test(
      'antrean kosong dan server tidak terjangkau: bukan "Sinkron selesai"',
      () async {
        final run = await v2SyncRound(
          run: () async => const V2SyncRun(),
          markSynced: fail,
        );
        expect(run.remaining, greaterThan(0));
        expect(run.sent, 0);
        expect(run.pending, greaterThan(0));
        expect(run.syncedAt, isNull);
      },
    );

    test(
      'data baru terkirim lalu pencatatan jam gagal: tetap selesai',
      () async {
        var trusted = false;
        final run = await v2SyncRound(
          run: () async => const V2SyncRun(sent: 1, total: 1),
          markSynced: ({bool trustLocal = false}) async {
            trusted = trustLocal;
            return _serverTime;
          },
        );
        expect(trusted, isTrue);
        expect(run.remaining, 0);
      },
    );

    test('baris masih tersisa: jam tidak dicatat', () async {
      var called = false;
      final run = await v2SyncRound(
        run: () async => const V2SyncRun(sent: 1, failed: 1, total: 2),
        markSynced: ({bool trustLocal = false}) async {
          called = true;
          return _serverTime;
        },
      );
      expect(called, isFalse);
      expect(run.remaining, 1);
    });
  });

  group('halaman Sinkron', () {
    V2SyncQueue emptyQueue() => V2SyncQueue(
      openStore: () async => null,
      serverOrigin: 'https://example.test',
      userId: '1',
    );

    testWidgets('tersambung ke antrean: jam contoh 09.40 tidak pernah tampil', (
      tester,
    ) async {
      final queue = emptyQueue();
      addTearDown(queue.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: V2SinkronPage(
            queue: queue,
            onSyncNow: (_) async => const V2SyncRun(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('09.40'), findsNothing);
    });

    testWidgets('galeri tanpa sambungan tetap memakai jam contoh desain', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: V2SinkronPage()));
      await tester.pumpAndSettle();
      expect(find.text('09.40'), findsOneWidget);
    });

    testWidgets('menampilkan jam sinkron tersimpan, bukan jam contoh', (
      tester,
    ) async {
      final queue = emptyQueue();
      addTearDown(queue.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: V2SinkronPage(
            queue: queue,
            lastSyncedAt: _serverTime,
            onSyncNow: (_) async => const V2SyncRun(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(v2SinkronJam(_serverTime)), findsOneWidget);
      expect(find.text('09.40'), findsNothing);
    });

    testWidgets(
      'keluar dari menu lalu masuk lagi: jam tetap jam sinkron terakhir',
      (tester) async {
        final store = await _store();
        final server = _FakeServer();
        final api = _api(server);
        addTearDown(api.close);
        final queue = emptyQueue();
        addTearDown(queue.dispose);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              syncStatusRepositoryProvider.overrideWithValue(_repo(api, store)),
            ],
            child: MaterialApp(home: _Host(queue: queue)),
          ),
        );
        await tester.pumpAndSettle();

        // Pertama kali: belum pernah sinkron, jam tidak dikarang.
        await tester.tap(find.text('Buka sinkron'));
        await tester.pumpAndSettle();
        expect(find.text('--.--'), findsOneWidget);
        expect(find.text('09.40'), findsNothing);

        // Klik "Sinkron sekarang": jam yang dicatat server tampil.
        await tester.tap(find.text('Sinkron sekarang'));
        await tester.pumpAndSettle(const Duration(seconds: 4));
        expect(find.text(v2SinkronJam(_serverTime)), findsOneWidget);
        expect(server.posts, 1);

        // Keluar dari menu, lalu buka lagi.
        Navigator.of(tester.element(find.byType(V2SinkronPage))).pop();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Buka sinkron'));
        await tester.pumpAndSettle();
        expect(find.text(v2SinkronJam(_serverTime)), findsOneWidget);
        expect(find.text('09.40'), findsNothing);
        expect(find.text('--.--'), findsNothing);
      },
    );

    testWidgets(
      'sinkron tanpa internet dan antrean kosong tidak mengaku selesai',
      (tester) async {
        final store = await _store();
        final server = _FakeServer(online: false);
        final api = _api(server);
        addTearDown(api.close);
        final queue = emptyQueue();
        addTearDown(queue.dispose);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              syncStatusRepositoryProvider.overrideWithValue(_repo(api, store)),
            ],
            child: MaterialApp(home: _Host(queue: queue)),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Buka sinkron'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sinkron sekarang'));
        await tester.pumpAndSettle(const Duration(seconds: 4));

        expect(find.text('Sinkron selesai'), findsNothing);
        expect(find.text('Offline. Data tersimpan di HP.'), findsOneWidget);
        expect(find.text('--.--'), findsNothing); // tidak lagi di ringkasan
      },
    );
  });
}

/// Meniru sambungan Beranda: jam diambil dari provider tiap kali menu dibuka.
class _Host extends ConsumerWidget {
  const _Host({required this.queue});

  final V2SyncQueue queue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(v2SyncStatusProvider);
    final status = ref.read(v2SyncStatusProvider.notifier);
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(context).push(
            V2SinkronPage.route(
              queue: queue,
              lastSyncedAt: last,
              refreshLastSync: status.refresh,
              recordSync: () => status.markSynced(trustLocal: true),
              onSyncNow: (onProgress) => v2SyncRound(
                run: () async => const V2SyncRun(),
                markSynced: status.markSynced,
              ),
            ),
          ),
          child: const Text('Buka sinkron'),
        ),
      ),
    );
  }
}
