import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/inventory_record.dart';
import '../data/repositories/inventory_repository.dart';
import '../data/services/api_client.dart';
import '../data/services/inventory_cache.dart';
import 'session_viewmodel.dart';

final inventoryCacheProvider = Provider<Future<InventoryCache>>((ref) {
  final cache = InventoryCache.open();
  ref.onDispose(() {
    unawaited(cache.then((db) => db.close()).catchError((_) {}));
  });
  return cache;
});

class ConnectedInventoryState {
  const ConnectedInventoryState({
    this.records = const [],
    this.loading = false,
    this.error,
    this.cached = false,
    this.fetchedAt,
  });
  final List<InventoryRecord> records;
  final bool loading, cached;
  final String? error;
  final DateTime? fetchedAt;
}

class ConnectedInventoryViewModel
    extends StateNotifier<ConnectedInventoryState> {
  ConnectedInventoryViewModel(
    this._repository, {
    ConnectedInventoryState? initialState,
    bool autoLoad = true,
  }) : super(initialState ?? const ConnectedInventoryState()) {
    if (autoLoad) unawaited(_load());
  }
  final InventoryRepository _repository;

  Future<void> _load() async {
    state = const ConnectedInventoryState(loading: true);
    try {
      final snapshot = await _repository.cached();
      if (!mounted) return;
      if (snapshot != null) {
        state = ConnectedInventoryState(
          records: snapshot.records,
          cached: true,
          fetchedAt: snapshot.fetchedAt,
        );
      }
    } catch (_) {
      // Try the server; refresh also reports a persistent storage failure.
    }
    if (mounted) {
      state = ConnectedInventoryState(
        records: state.records,
        cached: state.cached,
        fetchedAt: state.fetchedAt,
      );
      await refresh();
    }
  }

  Future<void> refresh() async {
    if (state.loading) return;
    state = ConnectedInventoryState(
      records: state.records,
      loading: true,
      cached: state.cached,
      fetchedAt: state.fetchedAt,
    );
    try {
      final snapshot = await _repository.refresh();
      if (mounted) {
        state = ConnectedInventoryState(
          records: snapshot.records,
          fetchedAt: snapshot.fetchedAt,
        );
      }
    } catch (error) {
      if (!mounted) return;
      final denied = error is ApiException && [401, 403].contains(error.status);
      state = ConnectedInventoryState(
        records: denied ? const [] : state.records,
        cached: !denied && state.fetchedAt != null,
        fetchedAt: denied ? null : state.fetchedAt,
        error: serviceError(error),
      );
    }
  }

  Future<void> deactivateItem(String id) async {
    await _repository.deactivateItem(id);
    await refresh();
  }
}

final connectedInventoryProvider =
    StateNotifierProvider.autoDispose<
      ConnectedInventoryViewModel,
      ConnectedInventoryState
    >((ref) {
      final user = ref.watch(sessionProvider.select((state) => state.user));
      if (user == null) throw StateError('Inventaris memerlukan sesi.');
      return ConnectedInventoryViewModel(
        InventoryRepository(
          ref.watch(apiClientProvider),
          ref.watch(inventoryCacheProvider),
          userId: user.id,
        ),
      );
    });
