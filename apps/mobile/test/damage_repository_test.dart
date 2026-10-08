import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/damage_record.dart';
import 'package:hidrosense_mobile/data/models/transfer_record.dart';
import 'package:hidrosense_mobile/data/repositories/damage_repository.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'support/damage_fixture.dart';

void main() {
  test(
    'loads every transfer and damage page with the correct domain filter',
    () async {
      final requests = <Uri>[];
      final api = apiFor((request) async {
        requests.add(request.url);
        final page = int.parse(request.url.queryParameters['page']!);
        final transfers = request.url.path.endsWith('pemindahan');
        final ids = page == 1 ? List.generate(100, (i) => '${i + 1}') : ['101'];
        return pageReply(
          ids
              .map(
                (id) => transfers ? transferJson(id: id) : damageJson(id: id),
              )
              .toList(),
          page: page,
          total: 101,
        );
      });
      addTearDown(api.close);
      final repository = DamageRepository(api);
      expect((await repository.listTransfers('1')).length, 101);
      expect((await repository.listDamages('1')).length, 101);
      expect(requests.map((r) => r.queryParameters['page']), [
        '1',
        '2',
        '1',
        '2',
      ]);
      expect(
        requests.every((r) => r.queryParameters['limit'] == '100'),
        isTrue,
      );
      expect(requests[0].queryParameters['id_meja'], '1');
      expect(requests[2].queryParameters['id_pemindahan'], '1');
    },
  );

  test(
    'POST maps contract fields and accepts 201 creation or 200 replay',
    () async {
      var calls = 0;
      final api = apiFor((request) async {
        expect(request.url.path, '/api/v1/kerusakan');
        expect(
          request.headers['Idempotency-Key'],
          'ed241e52-d67a-46d8-a23a-2dba1fb79390',
        );
        expect(jsonDecode(request.body), draft.toJson());
        return reply({
          'data': damageJson(),
          'replayed': calls++ > 0,
        }, status: calls == 1 ? 201 : 200);
      });
      addTearDown(api.close);
      final repo = DamageRepository(api);
      for (var i = 0; i < 2; i++) {
        final record = await repo.createDamage(
          draft,
          'ed241e52-d67a-46d8-a23a-2dba1fb79390',
        );
        expect(record.id, '1');
        expect(record.version, '1');
      }
    },
  );

  test('token rotation retries the exact payload and UUID', () async {
    final keys = <String?>[];
    final bodies = <String>[];
    final api = apiFor((request) async {
      if (request.url.path.endsWith('auth/refresh')) {
        return reply({
          'data': {'access_token': 'rotated', 'refresh_token': 'new-refresh'},
        });
      }
      keys.add(request.headers['Idempotency-Key']);
      bodies.add(request.body);
      if (keys.length == 1) {
        return reply({
          'error': {'code': 'EXPIRED', 'message': 'Expired'},
        }, status: 401);
      }
      return reply({'data': damageJson()});
    });
    addTearDown(api.close);
    await DamageRepository(
      api,
    ).createDamage(draft, 'ed241e52-d67a-46d8-a23a-2dba1fb79390');
    expect(keys[0], keys[1]);
    expect(bodies[0], bodies[1]);
  });

  test('rejects responses from a previous session', () async {
    final pending = Completer<void>();
    final api = apiFor((request) async {
      await pending.future;
      return pageReply([transferJson()]);
    });
    addTearDown(api.close);
    final result = DamageRepository(api).listTransfers('1');
    final expectation = expectLater(
      result,
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'SESSION_CHANGED'),
      ),
    );
    api.clearSession();
    pending.complete();
    await expectation;
  });

  test(
    'rejects duplicate, incomplete, malformed, or incorrectly scoped lists',
    () async {
      for (final body in [
        {
          'data': [transferJson(), transferJson()],
          'meta': {'page': 1, 'total': 2, 'total_pages': 1},
        },
        {
          'data': [],
          'meta': {'page': 1, 'total': 1, 'total_pages': 1},
        },
        {
          'data': [transferJson()],
          'meta': {'page': 1, 'total': 101, 'total_pages': 2},
        },
        {
          'data': [
            {...transferJson(), 'id_meja': '2'},
          ],
          'meta': {'page': 1, 'total': 1, 'total_pages': 1},
        },
        {
          'data': ['bad'],
          'meta': {'page': 1, 'total': 1, 'total_pages': 1},
        },
      ]) {
        final api = apiFor((_) async => reply(body));
        await expectLater(
          DamageRepository(api).listTransfers('1'),
          throwsFormatException,
        );
        api.close();
      }
    },
  );

  test(
    'models keep integer IDs as strings and reject invalid counts or identifiers',
    () {
      expect(
        TransferRecord.fromJson(transferJson(id: '9223372036854775807')).id,
        '9223372036854775807',
      );
      for (final json in [
        {...transferJson(), 'id_pemindahan': 1},
        {...transferJson(), 'tanaman_aktif': -1},
        {...transferJson(), 'jumlah_tanaman': 2.5},
      ]) {
        expect(() => TransferRecord.fromJson(json), throwsFormatException);
      }
      expect(
        () => DamageRecord.fromJson({...damageJson(), 'jumlah_tanaman': 0}),
        throwsFormatException,
      );
    },
  );
}
