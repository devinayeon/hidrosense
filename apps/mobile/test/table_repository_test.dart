import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/models/table_record.dart';
import 'package:hidrosense_mobile/data/repositories/table_repository.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:http/http.dart' as http;

class MockTableHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.Request request) handler;
  MockTableHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request as http.Request);
    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TableRepository fetchTables returns parsed records', () async {
    final mockClient = MockTableHttpClient((req) async {
      expect(req.url.path, '/api/v1/meja-tanam');
      return http.Response(
        jsonEncode({
          'success': true,
          'data': [
            {
              'id_meja': 'tbl-01',
              'kode_meja': 'M-01',
              'jumlah_lubang': 250,
              'status_meja': 'tersedia',
              'keterangan': 'Meja Sayur A',
              'tanaman_aktif': 100,
              'kapasitas_tersedia': 150,
            }
          ]
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final api = ApiClient(
      mockClient,
      baseUri: Uri.parse('http://localhost:3000/api/v1'),
      allowInsecureLocalhost: true,
    );
    api.setTokens(accessToken: 'token-abc', refreshToken: 'ref-xyz');
    final repo = TableRepository(api);

    final tables = await repo.fetchTables();
    expect(tables.length, 1);
    final t = tables.first;
    expect(t.id, 'tbl-01');
    expect(t.code, 'M-01');
    expect(t.holeCount, 250);
    expect(t.activePlants, 100);
    expect(t.availableCapacity, 150);
    expect(t.occupancyPercentage, 40);
    expect(t.isMaintenance, false);
  });

  test('TableRepository createTable sends correct json', () async {
    final mockClient = MockTableHttpClient((req) async {
      expect(req.method, 'POST');
      expect(req.url.path, '/api/v1/meja-tanam');
      final body = jsonDecode(req.body);
      expect(body['kode_meja'], 'M-02');
      expect(body['jumlah_lubang'], 300);
      expect(body['status_meja'], 'tersedia');
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'id_meja': 'tbl-02',
            'kode_meja': 'M-02',
            'jumlah_lubang': 300,
            'status_meja': 'tersedia',
            'tanaman_aktif': 0,
            'kapasitas_tersedia': 300,
          }
        }),
        201,
        headers: {'content-type': 'application/json'},
      );
    });

    final api = ApiClient(
      mockClient,
      baseUri: Uri.parse('http://localhost:3000/api/v1'),
      allowInsecureLocalhost: true,
    );
    api.setTokens(accessToken: 'token-abc', refreshToken: 'ref-xyz');
    final repo = TableRepository(api);

    final created = await repo.createTable(
      code: 'M-02',
      holeCount: 300,
      status: 'tersedia',
    );
    expect(created.id, 'tbl-02');
    expect(created.code, 'M-02');
    expect(created.holeCount, 300);
  });
}
