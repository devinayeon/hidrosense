import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/core/telemetry/ab_testing_service.dart';
import 'package:hidrosense_mobile/data/services/api_client.dart';
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

  Object? writeError;
  Future<List<EmployeeModel>> Function()? onGet;

  @override
  Future<List<EmployeeModel>> getEmployees({
    int? statusAktif,
    String? query,
  }) async {
    final handler = onGet;
    if (handler != null) return handler();
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
    final error = writeError;
    if (error != null) throw error;
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
    final error = writeError;
    if (error != null) throw error;
    final idx = mockData.indexWhere((e) => e.id == id);
    final old = mockData[idx];
    String? nullable(String? value, String? current) {
      if (value == null) return current;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    final updated = EmployeeModel(
      id: old.id,
      nama: nama ?? old.nama,
      username: username ?? old.username,
      email: nullable(email, old.email),
      noTelepon: nullable(noTelepon, old.noTelepon),
      alamat: nullable(alamat, old.alamat),
      statusAktif: old.statusAktif,
      role: old.role,
    );
    mockData[idx] = updated;
    return updated;
  }

  @override
  Future<void> deactivateEmployee(String id) async {
    final error = writeError;
    if (error != null) throw error;
    final idx = mockData.indexWhere((e) => e.id == id);
    mockData[idx] = mockData[idx].copyWith(statusAktif: 0);
  }

  @override
  Future<void> activateEmployee(String id) async {
    final error = writeError;
    if (error != null) throw error;
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

    test(
      'createEmployee logs telemetry event and adds record to list',
      () async {
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
        expect(
          events.any((e) => e['event'] == 'employee_onboarding_started'),
          true,
        );
        expect(
          events.any((e) => e['event'] == 'employee_created_success'),
          true,
        );
        vm.dispose();
      },
    );

    test(
      'deactivateEmployee and cancelDeactivation log respective telemetry',
      () async {
        final vm = EmployeeViewModel(repo, telemetry);
        await pumpEventQueue();

        vm.cancelDeactivation('2');
        expect(
          telemetry.loggedEvents.any(
            (e) =>
                e['event'] == 'employee_deactivation_cancelled' &&
                e['employee_id'] == '2',
          ),
          true,
        );

        final success = await vm.deactivateEmployee('2', 'Bambang Pamungkas');
        expect(success, true);
        expect(
          telemetry.loggedEvents.any(
            (e) =>
                e['event'] == 'employee_deactivation_triggered' &&
                e['employee_id'] == '2',
          ),
          true,
        );

        expect(vm.state.totalActive, 0);
        vm.dispose();
      },
    );

    test(
      'search and filter stay local while counts use all employees',
      () async {
        final vm = EmployeeViewModel(repo, telemetry);
        await pumpEventQueue();

        vm.setFilter(1);
        expect(vm.state.employees, hasLength(1));
        expect(vm.state.totalActive, 1);
        expect(vm.state.totalInactive, 1);

        vm.onSearchChanged('budi');
        expect(vm.state.employees, isEmpty);
        expect(vm.state.hasAnyEmployees, isTrue);
        expect(vm.state.hasActiveFilters, isTrue);
        expect(vm.state.totalActive, 1);
        expect(vm.state.totalInactive, 1);

        vm.resetFilters();
        expect(vm.state.employees, hasLength(2));
        expect(vm.state.filterStatus, isNull);
        expect(vm.state.searchQuery, isEmpty);
        vm.dispose();
      },
    );

    test('an older load cannot overwrite a newer one', () async {
      final vm = EmployeeViewModel(repo, telemetry);
      await pumpEventQueue();

      final older = Completer<List<EmployeeModel>>();
      repo.onGet = () => older.future;
      final first = vm.loadEmployees();
      repo.onGet = null;
      await vm.loadEmployees();
      expect(vm.state.employees, hasLength(2));

      older.complete(const [
        EmployeeModel(id: '99', nama: 'Data Lama', username: 'lama'),
      ]);
      await first;
      expect(vm.state.employees, hasLength(2));
      expect(vm.state.employees.any((e) => e.id == '99'), isFalse);
      vm.dispose();
    });

    test(
      'save errors stay in the form and action errors stay separate',
      () async {
        final vm = EmployeeViewModel(repo, telemetry);
        await pumpEventQueue();

        repo.writeError = const ApiException(
          409,
          'USERNAME_TAKEN',
          'Username sudah dipakai.',
        );
        vm.startOnboarding();
        final created = await vm.createEmployee(
          nama: 'Karyawan Baru',
          username: 'karyawan_baru',
          password: 'PasswordSuperAman2026!',
          duration: const Duration(seconds: 2),
        );
        expect(created, isFalse);
        expect(vm.state.saveError, contains('Username sudah digunakan'));
        expect(vm.state.actionError, isNull);
        expect(vm.state.errorMessage, isNull);

        vm.clearSaveError();
        expect(vm.state.saveError, isNull);

        final deactivated = await vm.deactivateEmployee('2', 'Bambang');
        expect(deactivated, isFalse);
        expect(vm.state.actionError, contains('Username sudah digunakan'));
        expect(vm.state.saveError, isNull);
        vm.dispose();
      },
    );

    test('empty optional fields are sent as clear instructions', () async {
      repo.mockData[0] = const EmployeeModel(
        id: '2',
        nama: 'Bambang Pamungkas',
        username: 'bambang',
        email: 'bambang@hidro.id',
        noTelepon: '+62 812-345',
        alamat: 'Kebun A',
        statusAktif: 1,
      );
      final vm = EmployeeViewModel(repo, telemetry);
      await pumpEventQueue();

      final success = await vm.updateEmployee(
        '2',
        email: '',
        noTelepon: '',
        alamat: '',
      );

      expect(success, isTrue);
      final updated = repo.mockData.firstWhere((e) => e.id == '2');
      expect(updated.email, isNull);
      expect(updated.noTelepon, isNull);
      expect(updated.alamat, isNull);
      expect(vm.state.saveError, isNull);
      vm.dispose();
    });
  });
}
