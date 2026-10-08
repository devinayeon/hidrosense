import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/core/telemetry/ab_testing_service.dart';
import 'package:hidrosense_mobile/features/accounts/data/models/employee_model.dart';
import 'package:hidrosense_mobile/features/accounts/data/repositories/employee_repository.dart';
import 'package:hidrosense_mobile/features/accounts/presentation/viewmodels/employee_viewmodel.dart';

class FakeEmployeeRepository implements EmployeeRepository {
  List<EmployeeModel> mockData = [
    const EmployeeModel(
      id: '2',
      nama: 'Bambang Pamungkas',
      username: 'bambang',
      statusAktif: 1,
    ),
    const EmployeeModel(
      id: '3',
      nama: 'Budi Santoso',
      username: 'budi',
      statusAktif: 0,
    ),
  ];

  @override
  Future<List<EmployeeModel>> getEmployees({
    int page = 1,
    int limit = 50,
    int? statusAktif,
    String? query,
  }) async {
    return mockData.where((e) {
      if (statusAktif != null && e.statusAktif != statusAktif) return false;
      if (query != null &&
          !e.nama.toLowerCase().contains(query.toLowerCase()) &&
          !e.username.toLowerCase().contains(query.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<EmployeeModel> getEmployeeDetail(String id) async {
    return mockData.firstWhere((e) => e.id == id);
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
    final newEmp = EmployeeModel(
      id: '4',
      nama: nama,
      username: username,
      email: email,
      noTelepon: noTelepon,
      alamat: alamat,
      statusAktif: 1,
    );
    mockData.add(newEmp);
    return newEmp;
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
    final idx = mockData.indexWhere((e) => e.id == id);
    final updated = mockData[idx].copyWith(
      nama: nama,
      username: username,
      email: email,
      noTelepon: noTelepon,
      alamat: alamat,
    );
    mockData[idx] = updated;
    return updated;
  }

  @override
  Future<void> deactivateEmployee(String id) async {
    final idx = mockData.indexWhere((e) => e.id == id);
    mockData[idx] = mockData[idx].copyWith(statusAktif: 0);
  }

  @override
  Future<void> activateEmployee(String id) async {
    final idx = mockData.indexWhere((e) => e.id == id);
    mockData[idx] = mockData[idx].copyWith(statusAktif: 1);
  }
}

void main() {
  group('EmployeeViewModel', () {
    late FakeEmployeeRepository repo;
    late AbTestingService telemetry;

    setUp(() {
      repo = FakeEmployeeRepository();
      telemetry = AbTestingService();
    });

    test('initializes by loading employees', () async {
      final vm = EmployeeViewModel(repo, telemetry);
      await pumpEventQueue();

      expect(vm.state.employees.length, 2);
      expect(vm.state.totalActive, 1);
      expect(vm.state.totalInactive, 1);
      expect(vm.state.isLoading, false);
      vm.dispose();
    });

    test('filters list by active status', () async {
      final vm = EmployeeViewModel(repo, telemetry);
      await pumpEventQueue();

      vm.setFilter(1);
      await pumpEventQueue();
      expect(vm.state.employees.length, 1);
      expect(vm.state.employees.first.nama, 'Bambang Pamungkas');

      vm.setFilter(0);
      await pumpEventQueue();
      expect(vm.state.employees.length, 1);
      expect(vm.state.employees.first.nama, 'Budi Santoso');

      vm.setFilter(null);
      await pumpEventQueue();
      expect(vm.state.employees.length, 2);
      vm.dispose();
    });

    test('createEmployee logs telemetry event and adds record to list', () async {
      final vm = EmployeeViewModel(repo, telemetry);
      await pumpEventQueue();

      vm.startOnboarding();
      final success = await vm.createEmployee(
        nama: 'Karyawan Baru',
        username: 'karyawan_baru',
        password: 'PasswordSuperAman2026!',
        duration: const Duration(seconds: 15),
      );

      expect(success, true);
      expect(vm.state.employees.length, 3);
      expect(vm.state.actionSuccessMessage, contains('Karyawan Baru'));

      final events = telemetry.loggedEvents;
      expect(events.any((e) => e['event'] == 'employee_onboarding_started'), true);
      expect(events.any((e) => e['event'] == 'employee_created_success'), true);
      vm.dispose();
    });

    test('deactivateEmployee and cancelDeactivation log respective telemetry', () async {
      final vm = EmployeeViewModel(repo, telemetry);
      await pumpEventQueue();

      vm.cancelDeactivation('2');
      expect(
        telemetry.loggedEvents.any(
          (e) => e['event'] == 'employee_deactivation_cancelled' && e['employee_id'] == '2',
        ),
        true,
      );

      final success = await vm.deactivateEmployee('2', 'Bambang Pamungkas');
      expect(success, true);
      expect(
        telemetry.loggedEvents.any(
          (e) => e['event'] == 'employee_deactivation_triggered' && e['employee_id'] == '2',
        ),
        true,
      );

      expect(vm.state.totalActive, 0);
      vm.dispose();
    });
  });
}
