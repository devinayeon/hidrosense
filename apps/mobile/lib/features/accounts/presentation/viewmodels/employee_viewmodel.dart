import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/services/api_client.dart';
import '../../../../core/telemetry/ab_testing_service.dart';
import '../../data/models/employee_model.dart';
import '../../data/repositories/employee_repository.dart';

@immutable
class EmployeeListState {
  const EmployeeListState({
    this.isLoading = false,
    this.isMutating = false,
    this.employees = const [],
    this.filterStatus,
    this.searchQuery = '',
    this.errorMessage,
    this.actionSuccessMessage,
  });

  final bool isLoading;
  final bool isMutating;
  final List<EmployeeModel> employees;
  final int? filterStatus; // null: Semua, 1: Aktif, 0: Nonaktif
  final String searchQuery;
  final String? errorMessage;
  final String? actionSuccessMessage;

  int get totalActive => employees.where((e) => e.isActive).length;
  int get totalInactive => employees.where((e) => !e.isActive).length;

  EmployeeListState copyWith({
    bool? isLoading,
    bool? isMutating,
    List<EmployeeModel>? employees,
    int? filterStatus,
    bool clearFilter = false,
    String? searchQuery,
    String? errorMessage,
    bool clearError = false,
    String? actionSuccessMessage,
    bool clearSuccess = false,
  }) {
    return EmployeeListState(
      isLoading: isLoading ?? this.isLoading,
      isMutating: isMutating ?? this.isMutating,
      employees: employees ?? this.employees,
      filterStatus: clearFilter ? null : (filterStatus ?? this.filterStatus),
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      actionSuccessMessage:
          clearSuccess ? null : (actionSuccessMessage ?? this.actionSuccessMessage),
    );
  }
}

class EmployeeViewModel extends StateNotifier<EmployeeListState> {
  EmployeeViewModel(this._repository, this._telemetry)
      : super(const EmployeeListState()) {
    loadEmployees();
  }

  final EmployeeRepository _repository;
  final AbTestingService _telemetry;
  Timer? _debounceTimer;

  Future<void> loadEmployees() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final list = await _repository.getEmployees(
        statusAktif: state.filterStatus,
        query: state.searchQuery.isEmpty ? null : state.searchQuery,
      );
      if (mounted) {
        state = state.copyWith(employees: list, isLoading: false);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: _formatError(e),
        );
      }
    }
  }

  void onSearchChanged(String query) {
    state = state.copyWith(searchQuery: query);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      loadEmployees();
    });
  }

  void setFilter(int? status) {
    if (state.filterStatus == status) return;
    state = state.copyWith(filterStatus: status, clearFilter: status == null);
    loadEmployees();
  }

  void startOnboarding() {
    _telemetry.logEvent('employee_onboarding_started');
  }

  Future<bool> createEmployee({
    required String nama,
    required String username,
    required String password,
    String? email,
    String? noTelepon,
    String? alamat,
    required Duration duration,
    int retryCount = 0,
  }) async {
    state = state.copyWith(isMutating: true, clearError: true, clearSuccess: true);
    try {
      final created = await _repository.createEmployee(
        nama: nama,
        username: username,
        password: password,
        email: email,
        noTelepon: noTelepon,
        alamat: alamat,
      );

      _telemetry.logEvent('employee_created_success', {
        'employee_id': created.id,
        'duration_ms': duration.inMilliseconds,
        'retry_count': retryCount,
      });

      await loadEmployees();
      if (mounted) {
        state = state.copyWith(
          isMutating: false,
          actionSuccessMessage: 'Pegawai ${created.nama} berhasil ditambahkan.',
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isMutating: false,
          errorMessage: _formatError(e),
        );
      }
      return false;
    }
  }

  Future<bool> updateEmployee(
    String id, {
    String? nama,
    String? username,
    String? password,
    String? email,
    String? noTelepon,
    String? alamat,
  }) async {
    state = state.copyWith(isMutating: true, clearError: true, clearSuccess: true);
    try {
      final updated = await _repository.updateEmployee(
        id,
        nama: nama,
        username: username,
        password: password,
        email: email,
        noTelepon: noTelepon,
        alamat: alamat,
      );
      await loadEmployees();
      if (mounted) {
        state = state.copyWith(
          isMutating: false,
          actionSuccessMessage: 'Data ${updated.nama} berhasil diperbarui.',
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isMutating: false,
          errorMessage: _formatError(e),
        );
      }
      return false;
    }
  }

  Future<bool> deactivateEmployee(String id, String nama) async {
    state = state.copyWith(isMutating: true, clearError: true, clearSuccess: true);
    try {
      await _repository.deactivateEmployee(id);
      _telemetry.logEvent('employee_deactivation_triggered', {'employee_id': id});
      await loadEmployees();
      if (mounted) {
        state = state.copyWith(
          isMutating: false,
          actionSuccessMessage: 'Akun $nama telah dinonaktifkan.',
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isMutating: false,
          errorMessage: _formatError(e),
        );
      }
      return false;
    }
  }

  void cancelDeactivation(String id) {
    _telemetry.logEvent('employee_deactivation_cancelled', {'employee_id': id});
  }

  Future<bool> activateEmployee(String id, String nama) async {
    state = state.copyWith(isMutating: true, clearError: true, clearSuccess: true);
    try {
      await _repository.activateEmployee(id);
      await loadEmployees();
      if (mounted) {
        state = state.copyWith(
          isMutating: false,
          actionSuccessMessage: 'Akun $nama berhasil diaktifkan kembali.',
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isMutating: false,
          errorMessage: _formatError(e),
        );
      }
      return false;
    }
  }

  String _formatError(Object error) {
    if (error is ApiException) {
      if (error.code == 'USERNAME_TAKEN') {
        return 'Username sudah digunakan oleh akun lain.';
      }
      if (error.code == 'ACCOUNT_DEACTIVATED') {
        return 'Akun sedang dinonaktifkan. Aktifkan kembali akun terlebih dahulu.';
      }
      if (error.code == 'VALIDATION_ERROR') {
        return 'Input data tidak valid. Periksa kembali form.';
      }
      return error.message;
    }
    if (error is FormatException) {
      return 'Format data tidak sesuai. Silakan muat ulang.';
    }
    return 'Terjadi kendala jaringan. Periksa koneksi Anda.';
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

final employeeViewModelProvider =
    StateNotifierProvider.autoDispose<EmployeeViewModel, EmployeeListState>((ref) {
  return EmployeeViewModel(
    ref.watch(employeeRepositoryProvider),
    ref.watch(abTestingServiceProvider),
  );
});
