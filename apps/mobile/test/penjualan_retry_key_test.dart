// Tes: kunci Idempotency-Key penjualan harus dipakai ulang saat percobaan
// ulang yang hasil sebelumnya tidak pasti (respons hilang / 5xx), supaya
// server tidak mencatat penjualan ganda. Kunci baru hanya dipakai untuk
// isian berbeda, setelah berhasil, atau setelah ditolak jelas oleh server.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hidrosense_mobile/data/models/sale_record.dart';
import 'package:hidrosense_mobile/data/repositories/harvest_repository.dart';
import 'package:hidrosense_mobile/data/repositories/sales_repository.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/viewmodels/penjualan_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';

import 'support/sales_fixture.dart';

const _draft = SalesDraft(
  date: '2026-11-01',
  buyer: 'Toko',
  status: 'lunas',
  harvestId: '1',
  quantity: 1,
  price: 1000,
);

const _otherDraft = SalesDraft(
  date: '2026-11-01',
  buyer: 'Toko',
  status: 'lunas',
  harvestId: '1',
  quantity: 2,
  price: 1000,
);

/// Membuat view model dengan klien palsu; [reply] menentukan jawaban POST ke-n.
(PenjualanViewModel, List<String>) _setup(
  http.Response Function(int attempt) reply, {
  int otherStatus = 503,
}) {
  final keys = <String>[];
  var posts = 0;
  final client = MockClient((request) async {
    if (request.method == 'POST' && request.url.path.endsWith('/penjualan')) {
      keys.add(request.headers['Idempotency-Key'] ?? '<none>');
      posts++;
      return reply(posts);
    }
    return http.Response(
      jsonEncode({
        'error': {'code': 'X', 'message': 'x'},
      }),
      otherStatus,
    );
  });
  final api = ApiClient(
    client,
    baseUri: Uri.parse('https://example.test/api/v1'),
  )..setTokens(accessToken: 'a', refreshToken: 'r');
  final vm = PenjualanViewModel(
    SalesRepository(api),
    HarvestRepository(api),
    autoLoad: false,
  );
  return (vm, keys);
}

http.Response _error(int status, String code) => http.Response(
  jsonEncode({
    'error': {'code': code, 'message': 'x'},
  }),
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

  // Isian yang berubah saat hasil belum pasti bisa menjadi penjualan kedua,
  // karena yang pertama mungkin sudah tersimpan di server.
  test(
    'isian berbeda saat hasil belum pasti: ditolak, tidak terkirim',
    () async {
      final (vm, keys) = _setup((_) => _error(503, 'X'));
      await _try(vm, _draft);
      await expectLater(
        vm.createSale(_otherDraft),
        throwsA(
          isA<ApiException>().having(
            (error) => error.code,
            'code',
            'SALE_RESULT_UNCERTAIN',
          ),
        ),
      );
      expect(keys.length, 1);
    },
  );

  test('ditolak jelas (422): kunci baru dan isian boleh berubah', () async {
    final (vm, keys) = _setup((_) => _error(422, 'VALIDATION_ERROR'));
    await _try(vm, _draft);
    await _try(vm, _draft);
    expect(keys[0], isNot(keys[1]));
    await _try(vm, _otherDraft);
    expect(keys.length, 3);
    expect(keys[2], isNot(keys[1]));
  });

  // 401, 403, dan 429 ditolak sebelum kunci diperiksa server, jadi tidak
  // menjawab apakah kiriman pertama yang hilang itu sudah tersimpan.
  test('kiriman pertama hilang lalu sesi berakhir: kuncian tetap', () async {
    final (vm, _) = _setup((n) {
      if (n == 1) throw http.ClientException('connection reset');
      return _error(401, 'UNAUTHENTICATED');
    }, otherStatus: 401);
    await _try(vm, _draft);
    await _try(vm, _draft);
    expect(vm.pendingCommand, isNotNull);
  });

  for (final status in [403, 429]) {
    test(
      'kiriman pertama hilang lalu $status: kunci dan kunciannya tetap',
      () async {
        final (vm, keys) = _setup((n) {
          if (n == 1) throw http.ClientException('connection reset');
          if (n == 2) return _error(status, 'X');
          return _error(503, 'X');
        });
        await _try(vm, _draft);
        await _try(vm, _draft);
        expect(vm.pendingCommand, isNotNull);
        await _try(vm, _draft);
        expect(keys.length, 3);
        expect(keys.toSet().length, 1);
      },
    );

    test('kiriman pertama langsung $status: tidak ada yang terkunci', () async {
      final (vm, _) = _setup((_) => _error(status, 'X'));
      await _try(vm, _draft);
      expect(vm.pendingCommand, isNull);
    });
  }

  // Halaman HTML dari proxy tidak berasal dari server kita, jadi kuncian tetap.
  for (final status in [404, 407, 408]) {
    test('kiriman pertama hilang lalu $status HTML: kuncian tetap', () async {
      final (vm, _) = _setup((n) {
        if (n == 1) throw http.ClientException('connection reset');
        return http.Response('<html>portal</html>', status);
      });
      await _try(vm, _draft);
      await _try(vm, _draft);
      expect(vm.pendingCommand, isNotNull);
    });
  }

  // Pindah tab membuang view model (autoDispose); kuncinya harus tetap ada.
  test('view model dibuang lalu dibuat lagi: kunci sama', () async {
    final keys = <String>[];
    final api = salesApi((request) async {
      if (request.method == 'POST') {
        keys.add(request.headers['Idempotency-Key'] ?? '<none>');
        throw http.ClientException('connection reset');
      }
      return _error(503, 'X');
    });
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    for (var i = 0; i < 2; i++) {
      final listener = container.listen(penjualanViewModelProvider, (_, _) {});
      final first = container.read(penjualanViewModelProvider.notifier);
      try {
        await first.createSale(_draft);
      } catch (_) {}
      listener.close();
      await container.pump();
      expect(
        first.mounted,
        isFalse,
        reason: 'view model harus benar-benar dibuang',
      );
    }
    expect(keys.length, 2);
    expect(keys[0], keys[1]);
  });

  test(
    'berhasil: penjualan baru dengan isian sama memakai kunci baru',
    () async {
      final (vm, keys) = _setup(
        (_) => http.Response(
          jsonEncode({
            'data': saleJson(
              date: '2026-11-01',
              buyer: 'Toko',
              details: [
                saleDetailJson(
                  harvestId: '1',
                  quantity: '1.00',
                  price: '1000.00',
                ),
              ],
            ),
            'operation': {'operation_key': 'x', 'revision': '1'},
            'replayed': false,
          }),
          201,
        ),
      );
      await vm.createSale(_draft);
      await vm.createSale(_draft);
      expect(keys.length, 2);
      expect(keys[0], isNot(keys[1]));
    },
  );
}
