import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/table_record.dart';
import '../data/repositories/table_repository.dart';
import 'session_viewmodel.dart';

final tableRepositoryProvider = Provider<TableRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return TableRepository(api);
});

class TableState {
  const TableState({
    this.records = const [],
    this.loading = false,
    this.error,
    this.searchQuery = '',
    this.statusFilter,
  });

  final List<TableRecord> records;
  final bool loading;
  final String? error;
  final String searchQuery;
  final String? statusFilter; // null = semua, 'tersedia', 'pemeliharaan', dsb.

  List<TableRecord> get filtered {
    return records.where((table) {
      if (statusFilter != null && table.status != statusFilter) {
        return false;
      }
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final matchCode = table.code.toLowerCase().contains(q);
        final matchNotes = table.notes?.toLowerCase().contains(q) ?? false;
        return matchCode || matchNotes;
      }
      return true;
    }).toList();
  }

  Map<String, int> get counts {
    int total = records.length;
    int active = 0;
    int maintenance = 0;
    for (final t in records) {
      if (t.isMaintenance) {
        maintenance++;
      } else {
        active++;
      }
    }
    return {'total': total, 'aktif': active, 'perawatan': maintenance};
  }

  TableState copyWith({
    List<TableRecord>? records,
    bool? loading,
    String? error,
    bool clearError = false,
    String? searchQuery,
    String? statusFilter,
    bool clearStatusFilter = false,
  }) {
    return TableState(
      records: records ?? this.records,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: clearStatusFilter
          ? null
          : (statusFilter ?? this.statusFilter),
    );
  }
}

class ConnectedTableNotifier extends StateNotifier<TableState> {
  ConnectedTableNotifier(this._repo) : super(const TableState()) {
    refresh();
  }

  final TableRepository _repo;

  Future<void> refresh() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final list = await _repo.fetchTables();
      if (mounted) state = state.copyWith(records: list, loading: false);
    } catch (e) {
      if (mounted) {
        state = state.copyWith(loading: false, error: serviceError(e));
      }
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setStatusFilter(String? status) {
    if (status == null) {
      state = state.copyWith(clearStatusFilter: true);
    } else {
      state = state.copyWith(statusFilter: status);
    }
  }

  Future<TableRecord> createTable({
    required String code,
    required int holeCount,
    String? status,
    String? notes,
  }) async {
    final created = await _repo.createTable(
      code: code,
      holeCount: holeCount,
      status: status,
      notes: notes,
    );
    state = state.copyWith(records: [created, ...state.records]);
    return created;
  }

  Future<TableRecord> updateTable(
    String id, {
    String? code,
    int? holeCount,
    String? status,
    String? notes,
  }) async {
    final updated = await _repo.updateTable(
      id,
      code: code,
      holeCount: holeCount,
      status: status,
      notes: notes,
    );
    state = state.copyWith(
      records: state.records.map((r) => r.id == id ? updated : r).toList(),
    );
    return updated;
  }
}

final connectedTableProvider =
    StateNotifierProvider<ConnectedTableNotifier, TableState>((ref) {
      final repo = ref.watch(tableRepositoryProvider);
      return ConnectedTableNotifier(repo);
    });
