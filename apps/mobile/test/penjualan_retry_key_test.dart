// Tes: kunci Idempotency-Key penjualan harus dipakai ulang saat percobaan
// ulang yang hasil sebelumnya tidak pasti (respons hilang / 5xx), supaya
// server tidak mencatat penjualan ganda. Kunci baru hanya dipakai untuk
// isian berbeda, setelah berhasil, atau setelah ditolak jelas oleh server.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hidrosense_mobile/data/models/sale_record.dart';
import 'package:hidrosense_mobile/data/repositories/harvest_repository.dart';
import 'package:hidrosense_mobile/data/repositories/sales_repository.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/viewmodels/penjualan_viewmodel.dart';

const _draft = SalesDraft(
  date: '2026-11-01',
  buyer: 'Toko',
  status: 'lunas',
  harvestId: '1',
  quantity: 1,
  price: 1000,
);

/// Membuat view model dengan klien palsu; [reply] menentukan jawaban POST ke-n.
(PenjualanViewModel, List<String>) _setup(
  http.Response Function(int attempt) reply,
) {
  final keys = <String>[];
  var posts = 0;
  final client = MockClient((request) async {
    if (request.method == 'POST' && request.url.path.endsWith('/penjualan')) {
      keys.add(request.headers['Idempotency-Key'] ?? '<none>');
      posts++;
      return reply(posts);
    }
    return http.Response(
      jsonEncode({'error': {'code': 'X', 'message': 'x'}}),
      503,
    );
  });
  final api = ApiClient(client, baseUri: Uri.parse('https://example.test/api/v1'))
    ..setTokens(accessToken: 'a', refreshToken: 'r');
  final vm = PenjualanViewModel(
    SalesRepository(api),
    HarvestRepository(api),
    autoLoad: false,
  );
  return (vm, keys);
}

http.Response _error(int status, String code) => http.Response(
  jsonEncode({'error': {'code': code, 'message': 'x'}}),
  status,
);

Future<void> _try(PenjualanViewModel vm, SalesDraft draft) async {
  try {
    await vm.createSale(draft);
  } catch (_) {}
}

void main() {
  test('respons hilang lalu coba lagi: kunci sama', () async {
    final (vm, keys) = _setup((n) {
      if (n == 1) throw http.ClientException('connection reset');
      return _error(503, 'X');
    });
    await _try(vm, _draft);
    await _try(vm, _draft);
    expect(keys.length, 2);
    expect(keys[0], keys[1], reason: 'kunci harus dipakai ulang');
  });

  test('server 503 lalu coba lagi: kunci sama', () async {
    final (vm, keys) = _setup((_) => _error(503, 'X'));
    await _try(vm, _draft);
    await _try(vm, _draft);
    expect(keys[0], keys[1]);
  });

  test('isian berbeda: kunci baru', () async {
    final (vm, keys) = _setup((_) => _error(503, 'X'));
    await _try(vm, _draft);
    await _try(
      vm,
      const SalesDraft(
        date: '2026-11-01',
        buyer: 'Toko',
        status: 'lunas',
        harvestId: '1',
        quantity: 2,
        price: 1000,
      ),
    );
    expect(keys[0], isNot(keys[1]));
  });

  test('ditolak jelas (422): percobaan berikutnya memakai kunci baru', () async {
    final (vm, keys) = _setup((_) => _error(422, 'VALIDATION_ERROR'));
    await _try(vm, _draft);
    await _try(vm, _draft);
    expect(keys[0], isNot(keys[1]));
  });
}
