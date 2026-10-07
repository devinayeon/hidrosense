import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response jsonResponse(int status, Object body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  test('POST auth retry preserves extension headers and exact body', () async {
    const key = '46375a8e-4687-4ff2-9ba0-28b51872bd10';
    final requests = <http.Request>[];
    final api = ApiClient(
      MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          expect(request.headers['Idempotency-Key'], isNull);
          return jsonResponse(200, {
            'data': {'access_token': 'new', 'refresh_token': 'refresh-2'},
          });
        }
        requests.add(request);
        if (requests.length == 1) {
          return jsonResponse(401, {
            'error': {'message': 'expired'},
          });
        }
        return jsonResponse(201, {'data': {}});
      }),
      baseUri: Uri.parse('https://example.test/api/v1'),
    )..setTokens(accessToken: 'old', refreshToken: 'refresh-1');
    await api.post(
      'pemindahan',
      headers: {'Idempotency-Key': key},
      body: {'id_penyemaian': 'sem-01', 'jumlah_tanaman': 10},
    );
    expect(requests, hasLength(2));
    expect(requests.map((request) => request.headers['Idempotency-Key']), [
      key,
      key,
    ]);
    expect(requests[1].body, requests[0].body);
    expect(requests.map((request) => request.headers['Authorization']), [
      'Bearer old',
      'Bearer new',
    ]);
    api.close();
  });

  test('parallel expired reads rotate once and retry with new token', () async {
    var refreshes = 0;
    final api = ApiClient(
      MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          return jsonResponse(200, {
            'data': {
              'access_token': 'old',
              'refresh_token': 'refresh-1',
              'user': {
                'id_user': '1',
                'nama': 'Petani',
                'username': 'p',
                'role': 'petani',
                'permissions': <String>['inventaris:read'],
              },
            },
          });
        }
        if (request.url.path.endsWith('/auth/refresh')) {
          refreshes++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return jsonResponse(200, {
            'data': {'access_token': 'new', 'refresh_token': 'refresh-2'},
          });
        }
        if (request.headers['authorization'] == 'Bearer old') {
          return jsonResponse(401, {
            'error': {'code': 'UNAUTHENTICATED', 'message': 'expired'},
          });
        }
        return jsonResponse(200, {
          'data': {'ok': true},
        });
      }),
      baseUri: Uri.parse('https://example.test/api/v1'),
    );
    expect((await api.login('p', 'secret')).id, '1');
    final results = await Future.wait([
      api.get('inventaris'),
      api.get('inventaris'),
    ]);
    expect(results.every((value) => value['data']['ok'] == true), isTrue);
    expect(refreshes, 1);
    api.close();
  });

  test('late login cannot restore a locally cleared session', () async {
    final pending = Completer<http.Response>();
    final api = ApiClient(
      MockClient((request) => pending.future),
      baseUri: Uri.parse('https://example.test/api/v1'),
    );
    final login = api.login('p', 'secret');
    api.clearSession();
    pending.complete(
      jsonResponse(200, {
        'data': {
          'access_token': 'late',
          'refresh_token': 'late-refresh',
          'user': {
            'id_user': '1',
            'nama': 'Petani',
            'username': 'p',
            'role': 'petani',
            'permissions': <String>[],
          },
        },
      }),
    );
    await expectLater(login, throwsA(isA<ApiException>()));
    await expectLater(api.get('inventaris'), throwsA(isA<ApiException>()));
    api.close();
  });
}
