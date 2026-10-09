import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/repositories/nursery_repository.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:http/http.dart' as http;

class MockNurseryHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.Request request) handler;
  MockNurseryHttpClient(this.handler);

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

  test('NurseryRepository listSowings returns parsed records', () async {
    final mockClient = MockNurseryHttpClient((req) async {
      expect(req.url.path, '/api/v1/penyemaian');
      return http.Response(
        jsonEncode({
          'success': true,
          'data': [
            {
              'id_penyemaian': 'sem-01',
              'id_user': 'usr-01',
              'tanggal_semai': '2026-10-01',
              'jumlah_benih': 200,
              'status_penyemaian': 'aktif',
              'usia_hari': 5,
              'siap_pindah': false,
              'keterangan': 'Batch Selada Hijau',
              'stok_konsumsi': [
                {'id_inventaris': 'inv-01', 'jumlah': '200', 'satuan': 'butir'},
              ],
            },
          ],
          'meta': {'page': 1, 'total': 1, 'total_pages': 1},
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
    final repo = NurseryRepository(api);

    final list = await repo.listSowings();
    expect(list.length, 1);
    expect(list.first.id, 'sem-01');
    expect(list.first.seedCount, 200);
    expect(list.first.materials.length, 1);
    expect(list.first.materials.first.inventoryId, 'inv-01');
  });

  test('NurseryRepository createSowing sends correct payload', () async {
    final mockClient = MockNurseryHttpClient((req) async {
      expect(req.method, 'POST');
      expect(req.url.path, '/api/v1/penyemaian');
      expect(
        req.headers['Idempotency-Key'] ?? req.headers['idempotency-key'],
        matches(RegExp(r'^[0-9a-fA-F-]{36}$')),
      );
      final body = jsonDecode(req.body);
      expect(body['tanggal_semai'], '2026-10-06');
      expect(body['jumlah_benih'], 150);
      expect(body['materials'].length, 1);
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'id_penyemaian': 'sem-new',
            'id_user': 'usr-01',
            'tanggal_semai': '2026-10-06',
            'jumlah_benih': 150,
            'status_penyemaian': 'aktif',
            'siap_pindah': false,
          },
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
    final repo = NurseryRepository(api);

    final rec = await repo.createSowing(
      sowingDate: '2026-10-06',
      seedCount: 150,
      note: 'Tes Semai',
      materials: [
        {'id_inventaris': 'inv-seed', 'jumlah': '150', 'satuan': 'butir'},
      ],
    );

    expect(rec.id, 'sem-new');
    expect(rec.seedCount, 150);
  });

  test(
    'NurseryRepository updateSowing sends PATCH with correct payload',
    () async {
      final mockClient = MockNurseryHttpClient((req) async {
        expect(req.method, 'PATCH');
        expect(req.url.path, '/api/v1/penyemaian/sem-01');
        final body = jsonDecode(req.body);
        expect(body['jumlah_benih'], 180);
        expect(body['keterangan'], 'Diperbarui');
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'id_penyemaian': 'sem-01',
              'id_user': 'usr-01',
              'tanggal_semai': '2026-10-01',
              'jumlah_benih': 180,
              'status_penyemaian': 'aktif',
              'siap_pindah': false,
              'keterangan': 'Diperbarui',
            },
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
      final repo = NurseryRepository(api);

      final rec = await repo.updateSowing(
        'sem-01',
        seedCount: 180,
        note: 'Diperbarui',
      );

      expect(rec.id, 'sem-01');
      expect(rec.seedCount, 180);
      expect(rec.note, 'Diperbarui');
    },
  );
}
