import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/pest_models.dart';
import '../../data/pest_repository.dart';
import '../../domain/pest_summary.dart';
import 'pest_providers.dart';
import 'recommendation_decider.dart';

class PestHistoryState {
  const PestHistoryState({
    this.items = const [],
    this.status,
    this.pest,
    this.tableId,
    this.page = 0,
    this.hasMore = true,
    this.loading = false,
    this.error,
  });

  final List<PestRecommendation> items;
  final RecommendationStatus? status;
  final PestKind? pest;

  /// Rotasi berlaku per meja, jadi riwayat bisa dipersempit ke satu meja.
  final String? tableId;
  final int page;
  final bool hasMore;
  final bool loading;
  final String? error;

  bool get isEmpty => !loading && error == null && items.isEmpty;

  PestHistoryState copyWith({
    List<PestRecommendation>? items,
    int? page,
    bool? hasMore,
    bool? loading,
    String? error,
    bool clearError = false,
  }) => PestHistoryState(
    items: items ?? this.items,
    status: status,
    pest: pest,
    tableId: tableId,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    loading: loading ?? this.loading,
    error: clearError ? null : error ?? this.error,
  );
}

/// Riwayat rekomendasi dengan filter status, hama, dan meja. Mengganti filter memuat ulang dari
/// awal; hasil muatan yang datang terlambat untuk filter lama dibuang.
class PestHistoryNotifier extends StateNotifier<PestHistoryState> {
  PestHistoryNotifier(this._repo, this._decider)
    : super(const PestHistoryState());

  final PestRepository _repo;
  final RecommendationDecider _decider;
  int _epoch = 0;

  Future<void> refresh() => _load(reset: true);

  Future<void> loadMore() async {
    if (state.loading || !state.hasMore) return;
    await _load(reset: false);
  }

  Future<void> setStatus(RecommendationStatus? status) {
    state = PestHistoryState(
      status: status,
      pest: state.pest,
      tableId: state.tableId,
    );
    return _load(reset: true);
  }

  Future<void> setPest(PestKind? pest) {
    state = PestHistoryState(
      status: state.status,
      pest: pest,
      tableId: state.tableId,
    );
    return _load(reset: true);
  }

  Future<void> setTable(String? tableId) {
    state = PestHistoryState(
      status: state.status,
      pest: state.pest,
      tableId: tableId,
    );
    return _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    final epoch = ++_epoch;
    state = state.copyWith(
      loading: true,
      clearError: true,
      page: reset ? 0 : null,
      hasMore: reset ? true : null,
    );
    try {
      final page = await _repo.list(
        status: state.status,
        pest: state.pest,
        tableId: state.tableId,
        page: reset ? 1 : state.page + 1,
      );
      if (epoch != _epoch) return;
      state = state.copyWith(
        items: reset ? page.items : [...state.items, ...page.items],
        page: page.page,
        hasMore: page.hasMore,
        loading: false,
      );
    } catch (error) {
      if (epoch != _epoch) return;
      state = state.copyWith(loading: false, error: pestErrorMessage(error));
    }
  }

  Future<String?> accept(
    String id, {
    String? note,
    List<StockLineDraft> materials = const [],
  }) => _apply(() => _decider.accept(id, note: note, materials: materials));

  Future<String?> reject(String id, RejectReason? reason, {String? note}) =>
      _apply(() => _decider.reject(id, reason, note: note));

  Future<String?> _apply(Future<PestRecommendation?> Function() call) async {
    try {
      final updated = await call();
      if (updated == null) return null;
      final status = state.status;
      // Bila filter aktif tidak lagi cocok dengan status baru, baris keluar dari daftar.
      state = state.copyWith(
        items: [
          for (final r in state.items)
            if (r.id != updated.id)
              r
            else if (status == null || updated.status == status)
              updated,
        ],
      );
      return null;
    } catch (error) {
      return pestErrorMessage(error);
    }
  }
}

final pestHistoryProvider =
    StateNotifierProvider.autoDispose<PestHistoryNotifier, PestHistoryState>((
      ref,
    ) {
      final repo = ref.watch(pestRepositoryProvider);
      return PestHistoryNotifier(repo, RecommendationDecider(repo));
    });
