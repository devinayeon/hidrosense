import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/services/api_client.dart';
import '../../../../viewmodels/session_viewmodel.dart';
import '../models/employee_model.dart';

abstract class EmployeeRepository {
  Future<List<EmployeeModel>> getEmployees({
    int page = 1,
    int limit = 50,
    int? statusAktif,
    String? query,
  });

  Future<EmployeeModel> getEmployeeDetail(String id);

  Future<EmployeeModel> createEmployee({
    required String nama,
    required String username,
    required String password,
    String? email,
    String? noTelepon,
    String? alamat,
  });

  Future<EmployeeModel> updateEmployee(
    String id, {
    String? nama,
    String? username,
    String? password,
    String? email,
    String? noTelepon,
    String? alamat,
  });

  Future<void> deactivateEmployee(String id);

  Future<void> activateEmployee(String id);
}

class EmployeeRepositoryImpl implements EmployeeRepository {
  EmployeeRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<List<EmployeeModel>> getEmployees({
    int page = 1,
    int limit = 50,
    int? statusAktif,
    String? query,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      if (statusAktif != null) 'status_aktif': statusAktif.toString(),
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
    };

    final response = await _api.get('employees', query: queryParams);
    final data = response['data'];
    if (data is! List) {
      throw const FormatException('Format data pegawai tidak valid.');
    }

    return data
        .map((item) => EmployeeModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<EmployeeModel> getEmployeeDetail(String id) async {
    final response = await _api.get('employees/$id');
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Data detail pegawai tidak valid.');
    }
    return EmployeeModel.fromJson(data);
  }

  @override
  Future<EmployeeModel> createEmployee({
    required String nama,
    required String username,
    required String password,
    String? email,
    String? noTelepon,
    String? alamat,
  }) async {
    final body = <String, dynamic>{
      'nama': nama.trim(),
      'username': username.trim(),
      'password': password,
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      if (noTelepon != null && noTelepon.trim().isNotEmpty)
        'no_telepon': noTelepon.trim(),
      if (alamat != null && alamat.trim().isNotEmpty) 'alamat': alamat.trim(),
    };

    final response = await _api.post('employees', body: body);
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Gagal membuat data pegawai.');
    }
    return EmployeeModel.fromJson(data);
  }

  @override
  Future<EmployeeModel> updateEmployee(
    String id, {
    String? nama,
    String? username,
    String? password,
    String? email,
    String? noTelepon,
    String? alamat,
  }) async {
    final body = <String, dynamic>{
      if (nama != null) 'nama': nama.trim(),
      if (username != null) 'username': username.trim(),
      if (password != null && password.isNotEmpty) 'password': password,
      if (email != null) 'email': email.trim().isEmpty ? null : email.trim(),
      if (noTelepon != null)
        'no_telepon': noTelepon.trim().isEmpty ? null : noTelepon.trim(),
      if (alamat != null)
        'alamat': alamat.trim().isEmpty ? null : alamat.trim(),
    };

    final response = await _api.patch('employees/$id', body: body);
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Gagal memperbarui data pegawai.');
    }
    return EmployeeModel.fromJson(data);
  }

  @override
  Future<void> deactivateEmployee(String id) async {
    await _api.post('employees/$id/deactivate');
  }

  @override
  Future<void> activateEmployee(String id) async {
    await _api.post('employees/$id/activate');
  }
}

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  return EmployeeRepositoryImpl(ref.watch(apiClientProvider));
});
