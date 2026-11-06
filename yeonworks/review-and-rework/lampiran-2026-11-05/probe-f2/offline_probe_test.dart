// Probes: offline login, restart without tokens, deactivate retry key, release-mode LAN http.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hidrosense_mobile/data/repositories/table_repository.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';

void main() {
  final offline = MockClient((_) async => throw const SocketException('Network is unreachable'));

  test('login with no network', () async {
    final api = ApiClient(offline, baseUri: Uri.parse('https://example.test/api/v1'));
    final vm = SessionViewModel(api);
    await vm.login('petani', 'x');
    // ignore: avoid_print
    print('offline login -> user=${vm.state.user} error="${vm.state.error}"');
    expect(vm.state.user, isNull);
  });

  test('fresh process (restart) has no tokens', () async {
    final api = ApiClient(offline, baseUri: Uri.parse('https://example.test/api/v1'));
    Object? err;
    try {
      await TableRepository(api).fetchTables();
    } catch (e) {
      err = e;
    }
    // ignore: avoid_print
    print('read after restart -> ${err is ApiException ? '${err.status} ${err.code}' : err}');
  });

  test('release build rejects LAN http backend', () async {
    final api = ApiClient(http.Client(), baseUri: Uri.parse('http://192.168.1.15:3000/api/v1'));
    Object? err;
    try {
      await api.login('a', 'b');
    } catch (e) {
      err = e;
    }
    // ignore: avoid_print
    print('release LAN http -> ${err is ApiException ? '${err.status} ${err.code}: ${err.message}' : err}');
  });

  test('table create retry with same command key', () async {
    final keys = <String>[];
    final client = MockClient((request) async {
      keys.add(request.headers['Idempotency-Key'] ?? '<none>');
      throw http.ClientException('reset');
    });
    final api = ApiClient(client, baseUri: Uri.parse('https://example.test/api/v1'))
      ..setTokens(accessToken: 'a', refreshToken: 'r');
    final repo = TableRepository(api);
    for (var i = 0; i < 2; i++) {
      try {
        await repo.createTable(code: 'M1', holeCount: 10);
      } catch (_) {}
    }
    // ignore: avoid_print
    print('repo-level createTable without key -> distinct=${keys.toSet().length} of ${keys.length}');
  });
}
