import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/inventory_record.dart';
import '../data/repositories/inventory_repository.dart';
import '../data/services/api_client.dart';
import '../data/services/inventory_cache.dart';
import 'session_viewmodel.dart';
import 'inventory_draft.dart';

final inventoryCacheProvider = Provider<Future<InventoryCache>>((ref) {
  final cache = InventoryCache.open();
  ref.onDispose(() {
    unawaited(cache.then((db) => db.close()).catchError((_) {}));
  });
  return cache;
});

// Manual retries survive auth expiry; commands are isolated by server/account.
final inventoryCommandsProvider = Provider(
  (ref) => <(String, String), InventorySaveCommand>{},
);

class ConnectedInventoryState {
  const ConnectedInventoryState({
    this.records = const [],
    this.loading = false,
    this.error,
    this.cached = false,
    this.fetchedAt,
    this.saving = false,
    this.pendingDraft,
    this.saveError,
    this.canFinishWithoutStock = false,
  });
  final List<InventoryRecord> records;
  final bool loading, cached;
  final String? error;
  final DateTime? fetchedAt;
  final bool saving;
  final InventoryDraft? pendingDraft;
  final String? saveError;
  final bool canFinishWithoutStock;

  ConnectedInventoryState withSave({
    required bool saving,
    InventoryDraft? draft,
    String? error,
    bool canFinishWithoutStock = false,
  }) => ConnectedInventoryState(
    records: records,
    loading: loading,
    error: this.error,
    cached: cached,
    fetchedAt: fetchedAt,
    saving: saving,
    pendingDraft: draft,
    saveError: error,
    canFinishWithoutStock: canFinishWithoutStock,
  );
}

class ConnectedInventoryViewModel
    extends StateNotifier<ConnectedInventoryState> {
  ConnectedInventoryViewModel(
    this._repository, {
    ConnectedInventoryState? initialState,
    bool autoLoad = true,
    Map<(String, String), InventorySaveCommand>? commands,
  }) : super(initialState ?? const ConnectedInventoryState()) {
    _commands = commands ?? {};
    if (_command != null) {
      state = state.withSave(
        saving: false,
        draft: _command!.draft,
        error: 'Penyimpanan sebelumnya belum selesai. Coba simpan lagi.',
        canFinishWithoutStock: _command!.canFinishWithoutStock,
      );
    }
    if (autoLoad) _initialLoad = _load();
  }
  final InventoryRepository _repository;
  Future<void>? _initialLoad, _refreshTask;
  late final Map<(String, String), InventorySaveCommand> _commands;
  (String, String) get _scope => (_repository.serverOrigin, _repository.userId);
  InventorySaveCommand? get _command => _commands[_scope];
  set _command(InventorySaveCommand? value) {
    if (value == null) {
      _commands.remove(_scope);
    } else {
      _commands[_scope] = value;
    }
  }

  void _setList(ConnectedInventoryState next) {
    state = next.withSave(
      saving: state.saving,
      draft: state.pendingDraft,
      error: state.saveError,
      canFinishWithoutStock: state.canFinishWithoutStock,
    );
  }

  Future<void> _load() async {
    _setList(const ConnectedInventoryState(loading: true));
    try {
      final snapshot = await _repository.cached();
      if (!mounted) return;
      if (snapshot != null) {
        _setList(
          ConnectedInventoryState(
            records: snapshot.records,
            cached: true,
            fetchedAt: snapshot.fetchedAt,
          ),
        );
      }
    } catch (_) {
      // Try the server; refresh also reports a persistent storage failure.
    }
    if (mounted) {
      _setList(
        ConnectedInventoryState(
          records: state.records,
          cached: state.cached,
          fetchedAt: state.fetchedAt,
        ),
      );
      await refresh();
    }
  }

  Future<void> refresh() {
    if (!mounted) return Future.value();
    return _refreshTask ??= _refresh().whenComplete(() => _refreshTask = null);
  }

  Future<void> _refresh() async {
    if (state.loading) return;
    _setList(
      ConnectedInventoryState(
        records: state.records,
        loading: true,
        cached: state.cached,
        fetchedAt: state.fetchedAt,
      ),
    );
    try {
      final snapshot = await _repository.refresh();
      if (mounted) {
        _setList(
          ConnectedInventoryState(
            records: snapshot.records,
            fetchedAt: snapshot.fetchedAt,
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      final denied = error is ApiException && [401, 403].contains(error.status);
      _setList(
        ConnectedInventoryState(
          records: denied ? const [] : state.records,
          cached: !denied && state.fetchedAt != null,
          fetchedAt: denied ? null : state.fetchedAt,
          error: serviceError(error),
        ),
      );
    }
  }

  /// Returns a refresh warning after a committed save, never a write failure.
  Future<String?> saveItem(InventoryDraft draft) async {
    if (!mounted || state.saving) return null;
    if (draft.errors.isNotEmpty) {
      throw StateError('Isian inventaris tidak valid.');
    }
    final command = _command ??= InventorySaveCommand(draft);
    if (command.draft.id != draft.id) {
      throw StateError(
        'Selesaikan penyimpanan barang sebelumnya terlebih dahulu.',
      );
    }
    final input = command.draft;
    final attempt = ++command.attempt;
    bool currentAttempt() =>
        identical(_command, command) && command.attempt == attempt;
    state = state.withSave(saving: true, draft: input);
    var previousUncertain = command.uncertain;
    final writingItem = command.item == null;
    command.canFinishWithoutStock = false;
    try {
      if (writingItem) {
        command.uncertain = true;
        final item = input.id == null
            ? await _repository.createItem(
                categoryId: input.categoryId,
                name: input.name,
                unit: input.unit,
                minimum: input.minimum.isEmpty ? null : input.minimum,
                idempotencyKey: command.itemKey,
              )
            : await _repository.updateItem(
                input.id!,
                categoryId: input.categoryId,
                name: input.name,
                unit: input.unit,
                minimum: input.minimum,
                idempotencyKey: command.itemKey,
              );
        if (!currentAttempt()) return null;
        command.item = item;
        previousUncertain = command.uncertain = false;
      }
      if (!mounted) return null;
      if (!command.stockSaved &&
          input.id == null &&
          InventoryDraft.hasStock(input.initialStock)) {
        command.uncertain = true;
        await _repository.recordStockMovement(
          direction: 'masuk',
          details: [
            {
              'id_inventaris': command.item!.id,
              'jumlah': input.initialStock,
              'satuan': input.unit,
            },
          ],
          note: 'Saldo awal registrasi barang',
          idempotencyKey: command.stockKey,
        );
        if (!currentAttempt()) return null;
        command.stockSaved = true;
        command.uncertain = false;
      }
    } catch (error) {
      if (!currentAttempt()) return null;
      final definiteRejection =
          error is ApiException &&
          error.code != 'SESSION_CHANGED' &&
          error.status >= 400 &&
          error.status < 500;
      command.uncertain = previousUncertain || !definiteRejection;
      command.canFinishWithoutStock =
          command.item != null && !command.uncertain;
      if (command.item == null && !command.uncertain) _command = null;
      if (!mounted) return null;
      state = state.withSave(
        saving: false,
        draft: _command?.draft,
        error:
            '${command.item != null ? 'Barang sudah tersimpan; saldo awal belum dikonfirmasi. ' : ''}${serviceError(error)}',
        canFinishWithoutStock: command.canFinishWithoutStock,
      );
      rethrow;
    }
    if (!mounted) return null;
    _command = null;
    return _finishSave();
  }

  Future<String?> _finishSave() async {
    // Finish any read started before the write, then fetch the committed state.
    await _initialLoad;
    await _refreshTask;
    if (!mounted) return null;
    await refresh();
    if (!mounted) return null;
    final warning = state.error;
    state = state.withSave(saving: false);
    return warning;
  }

  Future<String?> finishWithoutStock() async {
    if (!mounted || state.saving || _command?.canFinishWithoutStock != true) {
      throw StateError('Saldo awal belum dapat dipastikan. Coba simpan lagi.');
    }
    _command = null;
    state = state.withSave(saving: true);
    return _finishSave();
  }

  Future<void> deactivateItem(String id) async {
    await _repository.deactivateItem(id);
    await _initialLoad;
    await _refreshTask;
    if (mounted) await refresh();
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
        commands: ref.watch(inventoryCommandsProvider),
      );
    });
