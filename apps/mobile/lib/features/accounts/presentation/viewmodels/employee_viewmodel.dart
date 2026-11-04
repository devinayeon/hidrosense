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
    this.allEmployees = const [],
    this.filterStatus,
    this.searchQuery = '',
    this.errorMessage,
    this.saveError,
    this.actionError,
    this.actionSuccessMessage,
  });

  final bool isLoading;
  final bool isMutating;
  final List<EmployeeModel> allEmployees;
  final int? filterStatus; // null: Semua, 1: Aktif, 0: Nonaktif
  final String searchQuery;
  final String? errorMessage;
  final String? saveError;
  final String? actionError;
  final String? actionSuccessMessage;

  List<EmployeeModel> get employees {
    final query = searchQuery.trim().toLowerCase();
    return List.unmodifiable(
      allEmployees.where((employee) {
        if (filterStatus != null && employee.statusAktif != filterStatus) {
          return false;
        }
        if (query.isEmpty) return true;
        return employee.nama.toLowerCase().contains(query) ||
            employee.username.toLowerCase().contains(query);
      }),
    );
  }

  bool get hasAnyEmployees => allEmployees.isNotEmpty;
  bool get hasActiveFilters =>
      filterStatus != null || searchQuery.trim().isNotEmpty;
  int get totalActive => allEmployees.where((e) => e.isActive).length;
  int get totalInactive => allEmployees.where((e) => !e.isActive).length;

  EmployeeListState copyWith({
    bool? isLoading,
    bool? isMutating,
    List<EmployeeModel>? allEmployees,
    int? filterStatus,
    bool clearFilter = false,
    String? searchQuery,
    String? errorMessage,
    bool clearError = false,
    String? saveError,
    bool clearSaveError = false,
    String? actionError,
    bool clearActionError = false,
    String? actionSuccessMessage,
    bool clearSuccess = false,
  }) {
    return EmployeeListState(
      isLoading: isLoading ?? this.isLoading,
      isMutating: isMutating ?? this.isMutating,
      allEmployees: allEmployees ?? this.allEmployees,
      filterStatus: clearFilter ? null : (filterStatus ?? this.filterStatus),
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      saveError: clearSaveError ? null : (saveError ?? this.saveError),
      actionError: clearActionError ? null : (actionError ?? this.actionError),
      actionSuccessMessage: clearSuccess
          ? null
          : (actionSuccessMessage ?? this.actionSuccessMessage),
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
  int _loadGeneration = 0;

  Future<void> loadEmployees() async {
    final generation = ++_loadGeneration;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // Load-all keeps filter counts independent from the current page.
      final list = await _repository.getEmployees();
      if (!mounted || generation != _loadGeneration) return;
      state = state.copyWith(allEmployees: list, isLoading: false);
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      state = state.copyWith(isLoading: false, errorMessage: _formatError(e));
    }
  }

  void onSearchChanged(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setFilter(int? status) {
    if (state.filterStatus == status) return;
    state = state.copyWith(filterStatus: status, clearFilter: status == null);
  }

  void clearSaveError() {
    if (state.saveError == null) return;
    state = state.copyWith(clearSaveError: true);
  }

  void resetFilters() {
    state = state.copyWith(
      filterStatus: null,
      clearFilter: true,
      searchQuery: '',
    );
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
    state = state.copyWith(
      isMutating: true,
      clearError: true,
      clearSaveError: true,
      clearSuccess: true,
    );
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
        state = state.copyWith(isMutating: false, saveError: _formatError(e));
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
    state = state.copyWith(
      isMutating: true,
      clearError: true,
      clearSaveError: true,
      clearSuccess: true,
    );
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
        state = state.copyWith(isMutating: false, saveError: _formatError(e));
      }
      return false;
    }
  }

  Future<bool> deactivateEmployee(String id, String nama) async {
    state = state.copyWith(
      isMutating: true,
      clearError: true,
      clearActionError: true,
      clearSuccess: true,
    );
    try {
      await _repository.deactivateEmployee(id);
      _telemetry.logEvent('employee_deactivation_triggered', {
        'employee_id': id,
      });
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
        state = state.copyWith(isMutating: false, actionError: _formatError(e));
      }
      return false;
    }
  }

  void cancelDeactivation(String id) {
    _telemetry.logEvent('employee_deactivation_cancelled', {'employee_id': id});
  }

  Future<bool> activateEmployee(String id, String nama) async {
    state = state.copyWith(
      isMutating: true,
      clearError: true,
      clearActionError: true,
      clearSuccess: true,
    );
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
        state = state.copyWith(isMutating: false, actionError: _formatError(e));
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
    _loadGeneration++;
    super.dispose();
  }
}

final employeeViewModelProvider =
    StateNotifierProvider.autoDispose<EmployeeViewModel, EmployeeListState>((
      ref,
    ) {
      return EmployeeViewModel(
        ref.watch(employeeRepositoryProvider),
        ref.watch(abTestingServiceProvider),
      );
    });
