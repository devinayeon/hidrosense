import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/table_record.dart';
import 'package:hidrosense_mobile/data/repositories/table_repository.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/viewmodels/connected_table_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'support/damage_fixture.dart' show farmer;

Map<String, dynamic> record({
  String id = '9223372036854775806',
  String status = 'tersedia',
  String? notes = 'Catatan lama',
}) => {
  'id_meja': id,
  'kode_meja': 'M-$id',
  'jumlah_lubang': 250,
  'status_meja': status,
  'keterangan': notes,
  'tanaman_aktif': 0,
  'kapasitas_tersedia': 250,
  'public_id': 'af335604-91b3-4b39-946f-b50dcce2af5b',
  'version': '2',
};
Map<String, dynamic> page(List<Object> rows, {int number = 1, int? total}) => {
  'data': rows,
  'meta': {
    'page': number,
    'limit': 50,
    'total': total ?? rows.length,
    'total_pages': ((total ?? rows.length) / 50).ceil(),
  },
};
http.Response reply(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);
ApiClient client(
  Future<http.Response> Function(http.Request) handler, {
  String origin = 'https://tables.test/api/v1',
}) =>
    ApiClient(MockClient(handler), baseUri: Uri.parse(origin))
      ..setTokens(accessToken: 'access', refreshToken: 'refresh');
final uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

class TableTestSession extends SessionViewModel {
  TableTestSession(super.api) : super(initialState: const SessionState());
  void switchTo(SessionUser? user) => state = SessionState(user: user);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'all 51 tables load, preserving signed64 identity on the second page',
    () async {
      final visited = <String>[];
      final api = client((request) async {
        visited.add(request.url.queryParameters['page']!);
        expect(request.url.queryParameters['limit'], '50');
        return reply(
          visited.length == 1
              ? page(
                  List.generate(50, (i) => record(id: '${i + 1}')),
                  total: 51,
                )
              : page([record()], number: 2, total: 51),
        );
      });
      addTearDown(api.close);
      final tables = await TableRepository(api).fetchTables();
      expect(visited, ['1', '2']);
      expect(tables, hasLength(51));
      expect(tables.last.id, '9223372036854775806');
      expect(tables.last.publicId, record()['public_id']);
      expect(tables.last.version, '2');
    },
  );

  test(
    'invalid pagination and malformed records reject incomplete catalogs',
    () async {
      final malformed = [
        {'page': 2, 'limit': 50, 'total': 1, 'total_pages': 1},
        {'page': 1, 'limit': 49, 'total': 1, 'total_pages': 1},
        {'page': 1, 'total': 1, 'total_pages': 1},
        {'page': 1, 'limit': 50, 'total': -1, 'total_pages': 1},
        {'page': 1, 'limit': 50, 'total': 1, 'total_pages': 2},
        {'page': 1, 'limit': 50, 'total': 51, 'total_pages': 2},
      ];
      for (final meta in malformed) {
        final api = client(
          (_) async => reply({
            'data': [record()],
            'meta': meta,
          }),
        );
        await expectLater(
          TableRepository(api).fetchTables(),
          throwsFormatException,
          reason: '$meta',
        );
        api.close();
      }
      final api = client(
        (_) async => reply(
          page([
            {...record(), 'id_meja': 42},
          ]),
        ),
      );
      addTearDown(api.close);
      await expectLater(
        TableRepository(api).fetchTables(),
        throwsFormatException,
      );
    },
  );

  test(
    'duplicates across pages and changed totals reject partial catalogs',
    () async {
      for (final duplicate in [true, false]) {
        var requests = 0;
        final api = client(
          (_) async => reply(
            ++requests == 1
                ? page(
                    List.generate(50, (i) => record(id: '${i + 1}')),
                    total: 51,
                  )
                : page(
                    [record(id: duplicate ? '1' : '51')],
                    number: 2,
                    total: duplicate ? 51 : 52,
                  ),
          ),
        );
        await expectLater(
          TableRepository(api).fetchTables(),
          throwsFormatException,
        );
        expect(requests, 2);
        api.close();
      }
    },
  );

  test(
    'repository generates mutation UUIDs and sends explicit null notes',
    () async {
      final keys = <String>[];
      final api = client((request) async {
        keys.add(request.headers['Idempotency-Key']!);
        expect(keys.last, matches(uuid));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (request.method == 'PATCH') {
          expect(request.url.path, '/api/v1/meja-tanam/9223372036854775806');
          expect(body, {'keterangan': null});
        }
        return reply({
          'data': record(notes: null),
        }, request.method == 'POST' ? 201 : 200);
      });
      addTearDown(api.close);
      final repo = TableRepository(api);
      await repo.createTable(code: 'M-01', holeCount: 250);
      await repo.updateTable('9223372036854775806', notes: null);
      expect(keys.toSet(), hasLength(2));
    },
  );

  test(
    'filters count two active, three maintenance, and all seven statuses',
    () {
      final records =
          [
                'tersedia',
                'penuh',
                'pemeliharaan',
                'perbaikan',
                'rusak',
                'nonaktif',
                'custom',
              ].indexed
              .map(
                (entry) => TableRecord.fromJson(
                  record(id: '${entry.$1 + 1}', status: entry.$2),
                ),
              )
              .toList();
      final state = TableState(records: records);
      expect(state.counts, {'total': 7, 'aktif': 2, 'perawatan': 3});
      expect(state.copyWith(statusFilter: 'tersedia').filtered, hasLength(2));
      expect(
        state.copyWith(statusFilter: 'pemeliharaan').filtered,
        hasLength(3),
      );
      expect(state.filtered, hasLength(7));
      expect(state.filtered.last.statusLabel, 'custom');
    },
  );

  test(
    'double submit blocks immediately and stale initial read cannot replace receipt',
    () async {
      final initial = Completer<http.Response>(),
          posted = Completer<http.Response>();
      var reads = 0, writes = 0;
      final api = client((request) async {
        if (request.method == 'POST') {
          writes++;
          return posted.future;
        }
        return ++reads == 1 ? initial.future : reply(page([record()]));
      });
      addTearDown(api.close);
      final vm = ConnectedTableNotifier(TableRepository(api));
      addTearDown(vm.dispose);
      final saved = vm.createTable(code: 'M-01', holeCount: 250);
      expect(vm.submitting, isTrue);
      await expectLater(
        vm.createTable(code: 'M-01', holeCount: 250),
        throwsStateError,
      );
      await Future<void>.delayed(Duration.zero);
      expect(writes, 1);
      posted.complete(reply({'data': record()}, 201));
      await saved;
      initial.complete(reply(page([])));
      await Future<void>.delayed(Duration.zero);
      expect(vm.state.records.single.id, record()['id_meja']);
      expect(vm.submitting, isFalse);
      expect(reads, 2);
    },
  );

  for (final editing in [false, true]) {
    test(
      '${editing ? 'edit' : 'create'} timeout retries preserve payload and UUID across viewmodels',
      () async {
        final keys = <String>[], bodies = <String>[];
        final api = client((request) async {
          if (request.method == 'GET') return reply(page([]));
          keys.add(request.headers['Idempotency-Key']!);
          bodies.add(request.body);
          if (keys.length < 3) throw TimeoutException('Receipt lost');
          return reply({'data': record(notes: null)}, editing ? 200 : 201);
        });
        addTearDown(api.close);
        final commands = <(String, String), TableCommand>{};
        ConnectedTableNotifier make(String userId, [ApiClient? scopedApi]) =>
            ConnectedTableNotifier(
              TableRepository(scopedApi ?? api),
              userId: userId,
              commands: commands,
            );
        Future<TableRecord> save(
          ConnectedTableNotifier vm, {
          int count = 250,
        }) => editing
            ? vm.updateTable(
                '9223372036854775806',
                holeCount: count,
                notes: null,
              )
            : vm.createTable(code: 'M-01', holeCount: count, notes: null);
        final vm = make('1');
        await expectLater(save(vm), throwsA(isA<TimeoutException>()));
        expect(vm.payloadLocked, isTrue);
        await expectLater(save(vm, count: 999), throwsStateError);
        await expectLater(save(vm), throwsA(isA<TimeoutException>()));
        vm.dispose();
        final other = make('2');
        expect(other.pendingCommand, isNull);
        other.dispose();
        final otherApi = client(
          (_) async => reply(page([])),
          origin: 'https://other.test/api/v1',
        );
        addTearDown(otherApi.close);
        final otherServer = make('1', otherApi);
        expect(otherServer.pendingCommand, isNull);
        otherServer.dispose();
        final same = make('1');
        addTearDown(same.dispose);
        expect(same.payloadLocked, isTrue);
        await save(same);
        expect(keys, hasLength(3));
        expect(keys.toSet(), hasLength(1));
        expect(keys.first, matches(uuid));
        expect(bodies.toSet(), hasLength(1));
        if (editing) expect(jsonDecode(bodies.last)['keterangan'], isNull);
        expect(same.state.records.single.id, record()['id_meja']);
        expect(commands, isEmpty);
      },
    );
  }

  test(
    'provider isolates session state and enforces permissions before networking',
    () async {
      var reads = 0, writes = 0;
      final api = client((request) async {
        if (request.method == 'GET') {
          reads++;
          return reply(page([record()]));
        }
        writes++;
        return reply({'data': record()}, 201);
      });
      addTearDown(api.close);
      final session = TableTestSession(api);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          sessionProvider.overrideWith((ref) => session),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(connectedTableProvider, (_, _) {});
      addTearDown(subscription.close);
      final anonymous = container.read(connectedTableProvider.notifier);
      await expectLater(
        anonymous.createTable(code: 'X', holeCount: 250),
        throwsStateError,
      );
      expect(reads, 0);
      expect(writes, 0);
      session.switchTo(
        const SessionUser(
          id: '3',
          name: 'Reader',
          username: 'reader',
          role: 'pegawai',
          permissions: ['budidaya:read'],
        ),
      );
      final reader = container.read(connectedTableProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      expect(anonymous.mounted, isFalse);
      expect(reader.state.records, hasLength(1));
      await expectLater(reader.updateTable('1', notes: null), throwsStateError);
      expect(writes, 0);
      session.switchTo(farmer);
      final writer = container.read(connectedTableProvider.notifier);
      expect(reader.mounted, isFalse);
      await writer.createTable(code: 'X', holeCount: 250);
      await Future<void>.delayed(Duration.zero);
      expect(writes, 1);
      session.switchTo(null);
      final loggedOut = container.read(connectedTableProvider.notifier);
      expect(writer.mounted, isFalse);
      expect(loggedOut.state.records, isEmpty);
      await expectLater(
        writer.createTable(code: 'X', holeCount: 250),
        throwsStateError,
      );
      await Future<void>.delayed(Duration.zero);
      expect(writes, 1);
    },
  );
}
