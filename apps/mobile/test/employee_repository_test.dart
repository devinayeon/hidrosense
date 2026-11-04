import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
import 'package:hidrosense_mobile/features/accounts/data/repositories/employee_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response jsonReply(int status, Object body) =>
    http.Response(jsonEncode(body), status);

Map<String, dynamic> employeePage(
  List<Map<String, dynamic>> data, {
  int page = 1,
  int? total,
  int limit = 100,
}) {
  final count = total ?? data.length;
  return {
    'data': data,
    'meta': {
      'page': page,
      'limit': limit,
      'total': count,
      'total_pages': count == 0 ? 0 : (count + limit - 1) ~/ limit,
    },
  };
}

void main() {
  group('EmployeeRepositoryImpl', () {
    test('getEmployees passes query and filter parameters correctly', () async {
      final mockEmployees = [
        {
          'id_user': '2',
          'nama': 'Bambang Pamungkas',
          'username': 'bambang',
          'email': 'bambang@hidro.id',
          'no_telepon': '+62 812-345',
          'alamat': 'Kebun A',
          'status_aktif': 1,
          'role': 'pegawai',
        },
      ];

      final client = ApiClient(
        MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/employees');
          expect(request.url.queryParameters['status_aktif'], '1');
          expect(request.url.queryParameters['q'], 'bambang');
          expect(request.url.queryParameters['page'], '1');
          expect(request.url.queryParameters['limit'], '100');
          return jsonReply(200, employeePage(mockEmployees));
        }),
        baseUri: Uri.parse('http://localhost:3000/api/v1'),
        allowInsecureLocalhost: true,
      );
      client.setTokens(accessToken: 'mock_token', refreshToken: 'mock_refresh');

      final repo = EmployeeRepositoryImpl(client);
      final result = await repo.getEmployees(statusAktif: 1, query: 'bambang');

      expect(result.length, 1);
      expect(result.first.id, '2');
      expect(result.first.nama, 'Bambang Pamungkas');
      expect(result.first.isActive, true);
    });

    test('getEmployees loads every page without duplicate ids', () async {
      final pages = <int>[];
      Map<String, dynamic> employee(int i) => {
        'id_user': '${i + 1}',
        'nama': 'Pegawai ${i + 1}',
        'username': 'pegawai${i + 1}',
        'email': null,
        'no_telepon': null,
        'alamat': null,
        'status_aktif': 1,
        'role': 'pegawai',
      };

      final client = ApiClient(
        MockClient((request) async {
          final page = int.parse(request.url.queryParameters['page']!);
          pages.add(page);
          if (page == 1) {
            return jsonReply(
              200,
              employeePage(List.generate(100, employee), page: 1, total: 101),
            );
          }
          return jsonReply(
            200,
            employeePage([employee(100)], page: 2, total: 101),
          );
        }),
        baseUri: Uri.parse('http://localhost:3000/api/v1'),
        allowInsecureLocalhost: true,
      );
      client.setTokens(accessToken: 'mock_token', refreshToken: 'mock_refresh');

      final result = await EmployeeRepositoryImpl(client).getEmployees();

      expect(pages, [1, 2]);
      expect(result, hasLength(101));
      expect(result.first.id, '1');
      expect(result.last.id, '101');
    });

    test('getEmployees rejects missing or inconsistent meta', () async {
      final client = ApiClient(
        MockClient((request) async {
          return jsonReply(200, {
            'data': [
              {
                'id_user': '2',
                'nama': 'Bambang',
                'username': 'bambang',
                'status_aktif': 1,
              },
            ],
          });
        }),
        baseUri: Uri.parse('http://localhost:3000/api/v1'),
        allowInsecureLocalhost: true,
      );
      client.setTokens(accessToken: 'mock_token', refreshToken: 'mock_refresh');

      expect(
        () => EmployeeRepositoryImpl(client).getEmployees(),
        throwsA(isA<FormatException>()),
      );
    });

    test('createEmployee sends payload and parses created employee', () async {
      final createdData = {
        'id_user': '3',
        'nama': 'Siti Aminah',
        'username': 'aminah',
        'email': null,
        'no_telepon': null,
        'alamat': null,
        'status_aktif': 1,
        'role': 'pegawai',
      };

      final client = ApiClient(
        MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/employees');
          final body = jsonDecode(request.body);
          expect(body['nama'], 'Siti Aminah');
          expect(body['username'], 'aminah');
          expect(body['password'], 'RahasiaHidro2026!');
          return jsonReply(201, {'data': createdData});
        }),
        baseUri: Uri.parse('http://localhost:3000/api/v1'),
        allowInsecureLocalhost: true,
      );
      client.setTokens(accessToken: 'mock_token', refreshToken: 'mock_refresh');

      final repo = EmployeeRepositoryImpl(client);
      final employee = await repo.createEmployee(
        nama: 'Siti Aminah',
        username: 'aminah',
        password: 'RahasiaHidro2026!',
      );

      expect(employee.id, '3');
      expect(employee.nama, 'Siti Aminah');
      expect(employee.statusAktif, 1);
    });

    test('updateEmployee patches fields and parses updated employee', () async {
      final updatedData = {
        'id_user': '2',
        'nama': 'Nama Terupdate',
        'username': 'bambang',
        'email': null,
        'no_telepon': '+62 899-999',
        'alamat': null,
        'status_aktif': 1,
        'role': 'pegawai',
      };

      final client = ApiClient(
        MockClient((request) async {
          expect(request.method, 'PATCH');
          expect(request.url.path, '/api/v1/employees/2');
          final body = jsonDecode(request.body);
          expect(body['nama'], 'Nama Terupdate');
          expect(body['no_telepon'], '+62 899-999');
          return jsonReply(200, {'data': updatedData});
        }),
        baseUri: Uri.parse('http://localhost:3000/api/v1'),
        allowInsecureLocalhost: true,
      );
      client.setTokens(accessToken: 'mock_token', refreshToken: 'mock_refresh');

      final repo = EmployeeRepositoryImpl(client);
      final employee = await repo.updateEmployee(
        '2',
        nama: 'Nama Terupdate',
        noTelepon: '+62 899-999',
      );

      expect(employee.nama, 'Nama Terupdate');
      expect(employee.noTelepon, '+62 899-999');
    });

    test(
      'updateEmployee sends explicit null when clearing optional fields',
      () async {
        final updatedData = {
          'id_user': '2',
          'nama': 'Bambang Pamungkas',
          'username': 'bambang',
          'email': null,
          'no_telepon': null,
          'alamat': null,
          'status_aktif': 1,
          'role': 'pegawai',
        };

        final client = ApiClient(
          MockClient((request) async {
            expect(request.method, 'PATCH');
            expect(request.url.path, '/api/v1/employees/2');
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body.containsKey('email'), isTrue);
            expect(body['email'], isNull);
            expect(body.containsKey('no_telepon'), isTrue);
            expect(body['no_telepon'], isNull);
            expect(body.containsKey('alamat'), isTrue);
            expect(body['alamat'], isNull);
            expect(body.containsKey('nama'), isFalse);
            return jsonReply(200, {'data': updatedData});
          }),
          baseUri: Uri.parse('http://localhost:3000/api/v1'),
          allowInsecureLocalhost: true,
        );
        client.setTokens(
          accessToken: 'mock_token',
          refreshToken: 'mock_refresh',
        );

        final employee = await EmployeeRepositoryImpl(
          client,
        ).updateEmployee('2', email: '', noTelepon: '', alamat: '');

        expect(employee.email, isNull);
        expect(employee.noTelepon, isNull);
        expect(employee.alamat, isNull);
      },
    );

    test('deactivate and activate invoke endpoints correctly', () async {
      var deactivated = false;
      var activated = false;

      final client = ApiClient(
        MockClient((request) async {
          if (request.url.path == '/api/v1/employees/2/deactivate') {
            deactivated = true;
            return jsonReply(204, {});
          }
          if (request.url.path == '/api/v1/employees/2/activate') {
            activated = true;
            return jsonReply(204, {});
          }
          throw Exception('Unexpected path: ${request.url.path}');
        }),
        baseUri: Uri.parse('http://localhost:3000/api/v1'),
        allowInsecureLocalhost: true,
      );
      client.setTokens(accessToken: 'mock_token', refreshToken: 'mock_refresh');

      final repo = EmployeeRepositoryImpl(client);
      await repo.deactivateEmployee('2');
      await repo.activateEmployee('2');

      expect(deactivated, true);
      expect(activated, true);
    });
  });
}
