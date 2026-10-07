import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/nursery_record.dart';
import '../data/repositories/nursery_repository.dart';
import 'session_viewmodel.dart';

class ConnectedNurseryState {
  const ConnectedNurseryState({
    this.records = const [],
    this.loading = false,
    this.error,
    this.searchQuery = '',
    this.filterStatus,
  });

  final List<SowingRecord> records;
  final bool loading;
  final String? error;
  final String searchQuery;
  final String? filterStatus;

  List<SowingRecord> get filteredRecords {
    return records.where((item) {
      final matchStatus = filterStatus == null || item.status == filterStatus;
      final matchQuery =
          item.batchName.toLowerCase().contains(searchQuery.toLowerCase()) ||
          (item.note != null &&
              item.note!.toLowerCase().contains(searchQuery.toLowerCase()));
      return matchStatus && matchQuery;
    }).toList();
  }

  ConnectedNurseryState copyWith({
    List<SowingRecord>? records,
    bool? loading,
    String? error,
    String? searchQuery,
    String? filterStatus,
  }) {
    return ConnectedNurseryState(
      records: records ?? this.records,
      loading: loading ?? this.loading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      filterStatus: filterStatus ?? this.filterStatus,
    );
  }
}

class ConnectedNurseryViewModel extends StateNotifier<ConnectedNurseryState> {
  ConnectedNurseryViewModel(this._repository, {bool autoLoad = true})
    : super(const ConnectedNurseryState()) {
    if (autoLoad) refresh();
  }

  final NurseryRepository _repository;

  Future<void> transferSowing({
    required String sowingId,
    required String tableId,
    required String transferDate,
    required int plantCount,
    String? note,
  }) => _repository.transferSowing(
    sowingId: sowingId,
    tableId: tableId,
    transferDate: transferDate,
    plantCount: plantCount,
    note: note,
  );

  Future<void> refresh() async {
    if (state.loading) return;
    state = state.copyWith(loading: true, error: null);
    try {
      final list = await _repository.listSowings();
      if (mounted) {
        state = state.copyWith(records: list, loading: false);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(loading: false, error: serviceError(e));
      }
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query.trim());
  }

  void setFilterStatus(String? status) {
    state = state.copyWith(filterStatus: status);
  }

  Future<SowingRecord> createSowing({
    required String sowingDate,
    required int seedCount,
    String? note,
    required List<Map<String, dynamic>> materials,
  }) async {
    final record = await _repository.createSowing(
      sowingDate: sowingDate,
      seedCount: seedCount,
      note: note,
      materials: materials,
    );
    await refresh();
    return record;
  }

  Future<void> updateStatus(String id, String status) async {
    await _repository.updateSowing(id, status: status);
    await refresh();
  }
}

final nurseryRepositoryProvider = Provider<NurseryRepository>((ref) {
  return NurseryRepository(ref.watch(apiClientProvider));
});

final connectedNurseryProvider =
    StateNotifierProvider.autoDispose<
      ConnectedNurseryViewModel,
      ConnectedNurseryState
    >((ref) {
      final user = ref.watch(sessionProvider.select((state) => state.user));
      if (user == null) throw StateError('Penyemaian memerlukan sesi.');
      return ConnectedNurseryViewModel(ref.watch(nurseryRepositoryProvider));
    });
