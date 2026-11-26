import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../views/v2/components/v2_akun_employee.dart';
import '../../../views/v2/components/v2_akun_employee_store.dart';
import 'employee_errors.dart';
import 'models/employee_model.dart';
import 'repositories/employee_repository.dart';

/// Store akun pegawai v2 yang memakai API sungguhan.
///
/// Semua galat diterjemahkan lewat [employeeErrorMessage] lalu dibungkus
/// [V2EmployeeStoreException] supaya lapisan tampilan v2 tidak perlu tahu
/// kode galat server.
class V2EmployeeApiStore implements V2EmployeeStore {
  V2EmployeeApiStore(this._repository);

  final EmployeeRepository _repository;

  static V2Employee _toV2(EmployeeModel employee) => V2Employee(
    id: employee.id,
    name: employee.nama,
    username: employee.username,
    phone: employee.noTelepon ?? '',
    address: employee.alamat ?? '',
    active: employee.isActive,
  );

  @override
  Future<List<V2Employee>> list() async {
    try {
      final rows = await _repository.getEmployees();
      return List.unmodifiable(rows.map(_toV2));
    } catch (error) {
      throw V2EmployeeStoreException(employeeErrorMessage(error));
    }
  }

  @override
  Future<V2Employee> create(V2EmployeeDraft draft) async {
    try {
      final created = await _repository.createEmployee(
        nama: draft.name,
        username: draft.username,
        password: draft.password ?? '',
        noTelepon: draft.phone.isEmpty ? null : draft.phone,
        alamat: draft.address.isEmpty ? null : draft.address,
      );
      return _toV2(created);
    } catch (error) {
      throw V2EmployeeStoreException(employeeErrorMessage(error));
    }
  }

  @override
  Future<V2Employee> update(String id, V2EmployeeDraft draft) async {
    try {
      final updated = await _repository.updateEmployee(
        id,
        nama: draft.name,
        username: draft.username,
        password: draft.password,
        noTelepon: draft.phone,
        alamat: draft.address,
      );
      return _toV2(updated);
    } catch (error) {
      throw V2EmployeeStoreException(employeeErrorMessage(error));
    }
  }

  @override
  Future<V2Employee> deactivate(String id) async {
    try {
      await _repository.deactivateEmployee(id);
      return _toV2(await _repository.getEmployeeDetail(id));
    } catch (error) {
      throw V2EmployeeStoreException(employeeErrorMessage(error));
    }
  }

  @override
  Future<V2Employee> activate(String id) async {
    try {
      await _repository.activateEmployee(id);
      return _toV2(await _repository.getEmployeeDetail(id));
    } catch (error) {
      throw V2EmployeeStoreException(employeeErrorMessage(error));
    }
  }
}

final v2EmployeeStoreProvider = Provider<V2EmployeeStore>(
  (ref) => V2EmployeeApiStore(ref.watch(employeeRepositoryProvider)),
);
