// Probe: does a retried sale (after a lost response) reuse the Idempotency-Key?
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hidrosense_mobile/data/models/sale_record.dart';
import 'package:hidrosense_mobile/data/repositories/harvest_repository.dart';
import 'package:hidrosense_mobile/data/repositories/sales_repository.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/viewmodels/penjualan_viewmodel.dart';

void main() {
  test('sale create retry reuses Idempotency-Key', () async {
    final keys = <String>[];
    var posts = 0;
    final client = MockClient((request) async {
      if (request.method == 'POST' && request.url.path.endsWith('/penjualan')) {
        keys.add(request.headers['Idempotency-Key'] ?? '<none>');
        posts++;
        // First attempt: server committed, response lost (simulated timeout).
        if (posts == 1) throw http.ClientException('connection reset');
      }
      return http.Response(jsonEncode({'error': {'code': 'X', 'message': 'x'}}), 503);
    });
    final api = ApiClient(client, baseUri: Uri.parse('https://example.test/api/v1'))
      ..setTokens(accessToken: 'a', refreshToken: 'r');
    final vm = PenjualanViewModel(SalesRepository(api), HarvestRepository(api), autoLoad: false);
    const draft = SalesDraft(
      date: '2026-11-01', buyer: 'Toko', status: 'lunas', harvestId: '1',
      quantity: 1, price: 1000,
    );
    for (var i = 0; i < 2; i++) {
      try {
        await vm.createSale(draft);
      } catch (_) {}
    }
    // ignore: avoid_print
    print('keys sent: $keys');
    expect(keys.length, 2);
    expect(keys[0], keys[1], reason: 'retry must reuse the key, else duplicate sale');
  });
}
