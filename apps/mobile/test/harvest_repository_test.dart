import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/harvest_draft.dart';
import 'package:hidrosense_mobile/data/models/harvest_record.dart';
import 'package:hidrosense_mobile/data/repositories/harvest_repository.dart';
import 'support/harvest_fixture.dart';

void main() {
  test('exact decimal UI commas normalize; large IDs remain strings', () {
    expect(HarvestWeight.parse('99999999,99', ui: true).wire, '99999999.99');
    expect(
      HarvestWeight.parse('0.01').subtract(HarvestWeight.parse('0.00')).minor,
      BigInt.one,
    );
    final record = HarvestRecord.fromJson(harvestJson(id: '9007199254740993'));
    expect(record.id, '9007199254740993');
    expect(harvestDraft.toJson()['details'][0]['berat_total'], '2.50');
  });
  for (final invalid in [
    'NaN',
    'Infinity',
    '1e3',
    '-1',
    '1,2.3',
    '1.234',
    '100000000',
    '1\n',
    '1,000.00',
  ]) {
    test('rejects invalid exact decimal $invalid', () {
      expect(
        () => HarvestWeight.parse(invalid, ui: true),
        throwsFormatException,
      );
    });
  }
  test(
    'wire weights and IDs reject trailing newline and signed64 overflow',
    () {
      expect(() => HarvestWeight.parse('1\n'), throwsFormatException);
      for (final id in ['1\n', '9223372036854775808', '0']) {
        expect(
          () => HarvestRecord.fromJson(harvestJson(id: id)),
          throwsFormatException,
        );
      }
    },
  );
  test('legacy preserves unknown total/reject and accepts known saleable', () {
    final record = HarvestRecord.fromJson(harvestJson(legacy: true));
    expect(record.total, isNull);
    expect(record.reject, isNull);
    expect(record.saleable.wire, '2.25');
  });
  test(
    'header aggregate exceeds per detail max and legacy repeats transfer identity',
    () {
      final json = harvestJson(
        total: '99999999.99',
        reject: '0.00',
        layak: '99999999.99',
      );
      final first = (json['details'] as List).first as Map<String, dynamic>;
      json['details'] = [
        first,
        {...first, 'id_detail_panen': '2'},
      ];
      json['berat_total'] = '199999999.98';
      json['berat_layak'] = '199999999.98';
      expect(HarvestRecord.fromJson(json).total!.wire, '199999999.98');
    },
  );
  test(
    'strict full pagination loads 101 harvest snapshots and transfers without N+1',
    () async {
      final paths = <String>[];
      final api = harvestApi((request) async {
        paths.add(request.url.path);
        final page = int.parse(request.url.queryParameters['page']!);
        expect(request.url.queryParameters['limit'], '100');
        final ids = page == 1 ? List.generate(100, (i) => '${i + 1}') : ['101'];
        return harvestPage(
          ids
              .map(
                (id) => request.url.path.endsWith('panen')
                    ? harvestJson(id: id)
                    : harvestTransferJson(id: id),
              )
              .toList(),
          page: page,
          total: 101,
        );
      });
      addTearDown(api.close);
      final repo = HarvestRepository(api);
      expect((await repo.listHarvests()).length, 101);
      expect((await repo.listTransfers()).length, 101);
      expect(paths, [
        '/api/v1/panen',
        '/api/v1/panen',
        '/api/v1/pemindahan',
        '/api/v1/pemindahan',
      ]);
    },
  );
  for (final kind in [
    'metadata change',
    'duplicate',
    'short page',
    'wrong limit',
  ]) {
    test(
      'strict pagination rejects $kind and produces no partial result',
      () async {
        final api = harvestApi((request) async {
          final page = int.parse(request.url.queryParameters['page']!);
          final rows = page == 1
              ? List.generate(
                  kind == 'short page' ? 99 : 100,
                  (i) => harvestJson(id: '${i + 1}'),
                )
              : [harvestJson(id: kind == 'duplicate' ? '1' : '101')];
          if (kind == 'wrong limit') {
            return harvestReply({
              'data': rows,
              'meta': {'page': 1, 'limit': 20, 'total': 101, 'total_pages': 2},
            });
          }
          return harvestPage(
            rows,
            page: page,
            total: kind == 'metadata change' && page == 2 ? 102 : 101,
          );
        });
        addTearDown(api.close);
        expect(HarvestRepository(api).listHarvests(), throwsFormatException);
      },
    );
  }
  test(
    'POST sends exact contract payload and stable UUID for replay',
    () async {
      final key = '79464d5b-b494-48a5-9727-7b2b13dc4e35';
      var calls = 0;
      final api = harvestApi((request) async {
        expect(request.method, 'POST');
        expect(request.headers['Idempotency-Key'], key);
        expect(jsonDecode(request.body), harvestDraft.toJson());
        return harvestReply({
          'data': harvestJson(),
          'replayed': calls++ > 0,
        }, status: calls == 1 ? 201 : 200);
      });
      addTearDown(api.close);
      final repo = HarvestRepository(api);
      for (var i = 0; i < 2; i++) {
        expect(
          (await repo.write('create', harvestDraft.toJson(), key)).id,
          '1',
        );
      }
    },
  );
  test('token refresh retries identical payload and UUID', () async {
    final keys = <String?>[], bodies = <String>[];
    final api = harvestApi((request) async {
      if (request.url.path.endsWith('auth/refresh')) {
        return harvestReply({
          'data': {'access_token': 'rotated', 'refresh_token': 'new-refresh'},
        });
      }
      keys.add(request.headers['Idempotency-Key']);
      bodies.add(request.body);
      if (keys.length == 1) {
        return harvestReply({
          'error': {'code': 'TOKEN_EXPIRED', 'message': 'expired'},
        }, status: 401);
      }
      return harvestReply({'data': harvestJson()});
    });
    addTearDown(api.close);
    await HarvestRepository(api).write(
      'create',
      harvestDraft.toJson(),
      '79464d5b-b494-48a5-9727-7b2b13dc4e35',
    );
    expect(keys.length, 2);
    expect(keys[0], keys[1]);
    expect(bodies[0], bodies[1]);
  });
  test(
    'note null PATCH and wrong target or malformed receipts reject',
    () async {
      final correction = const HarvestCorrection(
        id: '1',
        expectedVersion: '1',
        note: '  ',
      );
      final api = harvestApi((request) async {
        expect(jsonDecode(request.body)['keterangan'], isNull);
        return harvestReply({'data': harvestJson(id: '2', version: '2')});
      });
      addTearDown(api.close);
      expect(
        HarvestRepository(api).write('1', correction.toJson(), 'key'),
        throwsFormatException,
      );
    },
  );
  test(
    'create receipt mismatching batch/date/count is uncertain invalid data',
    () async {
      final api = harvestApi(
        (_) async => harvestReply({'data': harvestJson(count: 6)}),
      );
      addTearDown(api.close);
      expect(
        HarvestRepository(api).write('create', harvestDraft.toJson(), 'key'),
        throwsFormatException,
      );
    },
  );
}
