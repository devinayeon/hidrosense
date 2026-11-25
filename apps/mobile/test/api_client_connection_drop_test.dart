import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Laporan pemilik (2026-11-23): internet ada, tetapi pertama kali membuka
// Penjualan muncul "Gagal memuat"; tombol "Coba lagi" langsung berhasil.
// Penyebab yang paling mungkin: sambungan keep-alive yang sudah basi ke server
// serverless putus pada permintaan pertama, dan permintaan kedua memakai
// sambungan baru.
http.Response _ok() => http.Response('{"data":{"ok":true}}', 200);

ApiClient _api(MockClient client) => ApiClient(
  client,
  baseUri: Uri.parse('https://example.test/api/v1'),
  connectionRetryDelay: Duration.zero,
)..setTokens(accessToken: 'access', refreshToken: 'refresh');

void main() {
  test(
    'GET pertama putus di tengah jalan: diulang sekali dan berhasil',
    () async {
      var calls = 0;
      final api = _api(
        MockClient((request) async {
          calls++;
          if (calls == 1) {
            throw http.ClientException(
              'Connection closed before full header was received',
            );
          }
          return _ok();
        }),
      );
      final response = await api.get('penjualan');
      expect(response['data'], {'ok': true});
      expect(calls, 2);
    },
  );

  test('GET: SocketException juga diulang sekali', () async {
    var calls = 0;
    final api = _api(
      MockClient((request) async {
        calls++;
        if (calls == 1) throw const SocketException('Connection reset');
        return _ok();
      }),
    );
    await api.get('penjualan');
    expect(calls, 2);
  });

  test(
    'GET yang tetap gagal setelah satu ulangan melempar galat aslinya',
    () async {
      var calls = 0;
      final api = _api(
        MockClient((request) async {
          calls++;
          throw http.ClientException('offline');
        }),
      );
      await expectLater(
        api.get('penjualan'),
        throwsA(isA<http.ClientException>()),
      );
      expect(calls, 2);
    },
  );

  test(
    'POST tidak diulang otomatis: kunci idempoten dikelola pemanggil',
    () async {
      var calls = 0;
      final api = _api(
        MockClient((request) async {
          calls++;
          throw http.ClientException('offline');
        }),
      );
      await expectLater(
        api.post('penjualan', body: {'a': 1}),
        throwsA(isA<http.ClientException>()),
      );
      expect(calls, 1);
    },
  );

  test('jawaban server (4xx/5xx) dan timeout tidak diulang', () async {
    var calls = 0;
    final failing = _api(
      MockClient((request) async {
        calls++;
        return http.Response('{"error":{"code":"X","message":"x"}}', 503);
      }),
    );
    await expectLater(failing.get('penjualan'), throwsA(isA<ApiException>()));
    expect(calls, 1);

    calls = 0;
    final timeout = _api(
      MockClient((request) async {
        calls++;
        throw TimeoutException('lambat');
      }),
    );
    await expectLater(
      timeout.get('penjualan'),
      throwsA(isA<TimeoutException>()),
    );
    expect(calls, 1);
  });

  // Pemulihan sesi di latar (auth/me) menghasilkan objek pengguna baru dengan
  // isi sama; tanpa kesamaan nilai itu terbaca sebagai pengguna berganti dan
  // membangun ulang semua provider per-pengguna di tengah pemuatan layar.
  test('SessionUser dengan isi sama dianggap sama', () {
    SessionUser user() => const SessionUser(
      id: '1',
      name: 'Budi',
      username: 'budi',
      role: 'petani',
      permissions: ['penjualan:read', 'cuaca:read'],
    );
    expect(user(), user());
    expect(user().hashCode, user().hashCode);
    expect(
      user(),
      isNot(
        const SessionUser(
          id: '1',
          name: 'Budi',
          username: 'budi',
          role: 'petani',
          permissions: ['penjualan:read'],
        ),
      ),
    );
  });
}
