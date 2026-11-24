// Regresi bug "login gagal hanya di APK release".
//
// Akar masalah: `apiClientProvider` mengirim `allowInsecureLocalhost: kDebugMode`
// sehingga build release menolak `http://<ip-lan>` (melempar `CONFIGURATION`) —
// v1 menampilkan "Alamat layanan belum dikonfigurasi...", v2 mengira perangkat
// offline. Perbaikan: release boleh cleartext ke host privat hanya bila di-opt-in
// lewat `--dart-define=ALLOW_INSECURE_HTTP=true`.
//
// `kDebugMode` tidak bisa diubah saat tes, karena itu keputusan build dipisah ke
// fungsi murni `allowInsecureHttp` yang bisa diuji di sini.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(int status, Object body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, Object> _loginBody() => {
  'data': {
    'access_token': 'access-1',
    'refresh_token': 'refresh-1',
    'user': {
      'id_user': '1',
      'nama': 'Petani',
      'username': 'petani',
      'role': 'petani',
      'permissions': <String>[],
    },
  },
};

void main() {
  group('allowInsecureHttp (keputusan build)', () {
    test('release tanpa opt-in menolak cleartext', () {
      expect(allowInsecureHttp(debugMode: false, buildFlag: false), isFalse);
    });

    test('release dengan ALLOW_INSECURE_HTTP=true mengizinkan', () {
      expect(allowInsecureHttp(debugMode: false, buildFlag: true), isTrue);
    });

    test('debug selalu mengizinkan', () {
      expect(allowInsecureHttp(debugMode: true, buildFlag: false), isTrue);
    });
  });

  test('resolveApiBaseUri mempertahankan skema http pada host LAN', () {
    final uri = resolveApiBaseUri('http://192.168.1.9:3000/');
    expect(uri.scheme, 'http');
    expect(uri.host, '192.168.1.9');
    expect(uri.path, '/api/v1');
  });

  group('ApiClient menolak/menerima http sesuai opt-in', () {
    test('http LAN ditolak saat allowInsecureLocalhost=false '
        '(perilaku release yang bikin gagal login)', () async {
      final api = ApiClient(
        MockClient((_) async => _json(200, _loginBody())),
        baseUri: Uri.parse('http://192.168.1.9:3000/api/v1'),
        allowInsecureLocalhost: false,
      );
      await expectLater(
        api.login('petani', 'secret'),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'kode', 'CONFIGURATION'),
        ),
      );
      api.close();
    });

    test('http LAN diterima saat opt-in aktif (inti perbaikan)', () async {
      final api = ApiClient(
        MockClient((_) async => _json(200, _loginBody())),
        baseUri: Uri.parse('http://192.168.1.9:3000/api/v1'),
        allowInsecureLocalhost: true,
      );
      final user = await api.login('petani', 'secret');
      expect(user.username, 'petani');
      api.close();
    });

    test('http host publik tetap ditolak walau opt-in aktif', () async {
      final api = ApiClient(
        MockClient((_) async => _json(200, _loginBody())),
        baseUri: Uri.parse('http://example.com/api/v1'),
        allowInsecureLocalhost: true,
      );
      await expectLater(
        api.login('petani', 'secret'),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'kode', 'CONFIGURATION'),
        ),
      );
      api.close();
    });

    test('https diterima tanpa opt-in', () async {
      final api = ApiClient(
        MockClient((_) async => _json(200, _loginBody())),
        baseUri: Uri.parse('https://api.hidrosense.test/api/v1'),
      );
      final user = await api.login('petani', 'secret');
      expect(user.username, 'petani');
      api.close();
    });
  });
}
