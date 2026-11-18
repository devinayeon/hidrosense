import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/harvest_record.dart';
import '../data/models/sale_record.dart';
import '../data/repositories/harvest_repository.dart';
import '../data/repositories/sales_repository.dart';
import '../data/services/api_client.dart';
import '../data/services/write_outcome.dart';
import '../models/penjualan_model.dart';
import 'panen_viewmodel.dart';
import 'penjualan_mappers.dart';
import 'sale_command.dart';
import 'session_viewmodel.dart';

// Provider daftar dan total ada di berkas sendiri; diekspor agar pemakai lama tetap jalan.
export 'penjualan_list_providers.dart';

enum PenjualanFilterCategory { all, lunas, belumLunas }

class PenjualanState {
  const PenjualanState({
    this.items = const [],
    this.batches = const [],
    this.loading = false,
    this.refreshing = false,
    this.salesLoaded = false,
    this.error,
  });

  final List<PenjualanItem> items;
  final List<BatchPanen> batches;
  final bool loading, refreshing, salesLoaded;
  final String? error;

  bool get isInitialLoading => loading && items.isEmpty;
}

class PenjualanViewModel extends StateNotifier<PenjualanState> {
  PenjualanViewModel(
    this._sales,
    this._harvests, {
    bool autoLoad = true,
    String userId = '',
    Map<SaleCommandScope, SaleCommand>? commands,
  }) : _commands = commands ?? {},
       _scope = (_sales.serverOrigin, userId),
       super(const PenjualanState()) {
    if (autoLoad) refresh();
  }

  final SalesRepository _sales;
  final HarvestRepository _harvests;
  final Map<SaleCommandScope, SaleCommand> _commands;
  final SaleCommandScope _scope;
  Future<void>? _refreshTask;
  int _generation = 0;

  Future<void> fetchPenjualanData() => refresh();

  /// Keadaan terakhir untuk lapisan tampilan lain (alur v2), tanpa mengubah
  /// notifier itu sendiri.
  PenjualanState get current => state;

  Future<void> refresh({bool force = false}) {
    final running = _refreshTask;
    if (!force && running != null) return running;
    final task = _refresh();
    _refreshTask = task;
    task.whenComplete(() {
      if (identical(_refreshTask, task)) _refreshTask = null;
    });
    return task;
  }

  Future<void> _refresh() async {
    final generation = ++_generation;
    if (!mounted) return;
    state = PenjualanState(
      items: state.items,
      batches: state.batches,
      loading: state.items.isEmpty,
      refreshing: state.items.isNotEmpty,
      salesLoaded: state.salesLoaded,
    );
    try {
      final results = await Future.wait<Object>([
        _sales.listSales(),
        _harvests.listHarvests().then<Object>(
          (value) => value,
          onError: (Object error) => error,
        ),
      ]);
      if (!mounted || generation != _generation) return;
      final salesResult = results[0];
      final harvestResult = results[1];
      if (salesResult is! List<SaleRecord>) {
        throw const FormatException('Daftar penjualan tidak valid.');
      }
      final records = salesResult;
      if (harvestResult is List<HarvestRecord>) {
        state = PenjualanState(
          items: List.unmodifiable(records.map(toPenjualanItem)),
          batches: toBatches(harvestResult, records),
          salesLoaded: true,
        );
      } else {
        state = PenjualanState(
          items: List.unmodifiable(records.map(toPenjualanItem)),
          batches: state.batches,
          salesLoaded: true,
          error: serviceError(harvestResult),
        );
      }
    } catch (error) {
      if (!mounted || generation != _generation) return;
      final denied =
          error is ApiException && (error.status == 401 || error.status == 403);
      state = PenjualanState(
        items: denied ? const [] : state.items,
        batches: denied ? const [] : state.batches,
        salesLoaded: denied ? false : state.salesLoaded,
        error: serviceError(error),
      );
    }
  }

  /// Tulis yang sedang berjalan atau hasilnya belum pasti, milik pengguna ini.
  SaleCommand? get pendingCommand => _commands[_scope];

  /// Tulis yang gagal tanpa jawaban pasti. Hanya ini yang mengunci formulir;
  /// kiriman yang masih berjalan belum tentu bermasalah.
  SaleCommand? get uncertainCommand {
    final pending = pendingCommand;
    return pending?.uncertain == true ? pending : null;
  }

  /// Mengirim [fresh], atau perintah tertunda bila isinya sama. Selama ada
  /// perintah tertunda, isian lain ditolak: yang pertama mungkin sudah tersimpan.
  Future<SaleRecord> _run(SaleCommand fresh) async {
    final pending = _commands[_scope];
    if (pending != null &&
        (pending.target != fresh.target || pending.payload != fresh.payload)) {
      throw saleBlockedError(pending);
    }
    final command = pending ?? fresh;
    final wasUncertain = command.uncertain;
    _commands[_scope] = command;
    try {
      final record = await command.write(_sales, command.key);
      _commands.remove(_scope);
      return record;
    } catch (error) {
      command.uncertain = writeStaysUncertain(
        error,
        wasUncertain: wasUncertain,
      );
      if (!command.uncertain) _commands.remove(_scope);
      rethrow;
    }
  }

  /// Melepas isian yang terkunci atas keputusan pengguna, setelah diperingatkan.
  /// Kiriman ulang bisa terus gagal, dan pengguna tidak boleh terkunci selamanya.
  /// Kiriman yang masih berjalan tidak bisa dibuang.
  void discardPending() {
    if (uncertainCommand != null) _commands.remove(_scope);
  }

  Future<PenjualanItem> _finish(SaleRecord record, PenjualanItem? old) async {
    final item = toPenjualanItem(record);
    if (mounted) _merge(oldItem: old, newItem: item);
    await refresh(force: true);
    return item;
  }

  /// Mengirim ulang isi yang sama persis. Server mengenali kuncinya, jadi bila
  /// kiriman pertama sudah tersimpan, tidak ada penjualan kedua.
  Future<PenjualanItem> retryPending() async {
    final command = pendingCommand;
    if (command == null) throw StateError('Tidak ada penjualan tertunda.');
    return _finish(await _run(command), command.oldItem);
  }

  Future<PenjualanItem> createSale(SalesDraft draft) async {
    final record = await _run(
      SaleCommand(
        target: saleCreateTarget,
        payload: jsonEncode(draft.toJson()),
        draft: draft,
        write: (sales, key) => sales.createSale(draft, key),
      ),
    );
    return _finish(record, null);
  }

  Future<PenjualanItem> updateSale(
    PenjualanItem existing,
    SalesDraft draft,
  ) async {
    final version = existing.version;
    if (!existing.canEditDetails || version == null) {
      throw const FormatException(
        'Rincian transaksi ini belum dapat diedit dari aplikasi.',
      );
    }
    // Versi tidak ikut payload: kiriman pertama yang tersimpan menaikkan versi,
    // dan pengiriman ulang tetap harus memakai versi lama agar tiketnya cocok.
    final record = await _run(
      SaleCommand(
        target: existing.id,
        payload: jsonEncode(draft.toJson()),
        draft: draft,
        oldItem: existing,
        write: (sales, key) =>
            sales.updateSale(existing.id, draft, version, key),
      ),
    );
    return _finish(record, existing);
  }

  Future<PenjualanItem> updateSaleHeader(
    PenjualanItem existing,
    SalesHeaderDraft draft,
  ) async {
    final version = existing.version;
    if (!existing.canEdit || version == null) {
      throw const FormatException(
        'Transaksi ini belum dapat diedit dari aplikasi.',
      );
    }
    final record = await _run(
      SaleCommand(
        target: existing.id,
        payload: jsonEncode(draft.toJson('')),
        headerDraft: draft,
        oldItem: existing,
        write: (sales, key) =>
            sales.updateSaleHeader(existing.id, draft, version, key),
      ),
    );
    return _finish(record, existing);
  }

  void _merge({PenjualanItem? oldItem, required PenjualanItem newItem}) {
    final byId = <String, PenjualanItem>{
      for (final item in state.items) item.id: item,
      newItem.id: newItem,
    };
    final items = byId.values.toList()..sort(comparePenjualanItems);
    state = PenjualanState(
      items: List.unmodifiable(items),
      batches: adjustBatches(state.batches, oldItem, newItem),
      salesLoaded: true,
    );
  }
}

final penjualanClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final salesRepositoryProvider = Provider(
  (ref) => SalesRepository(ref.watch(apiClientProvider)),
);

final penjualanViewModelProvider =
    StateNotifierProvider.autoDispose<PenjualanViewModel, PenjualanState>((
      ref,
    ) {
      final user = ref.watch(sessionProvider.select((state) => state.user));
      final canRead =
          user != null && user.permissions.contains('penjualan:read');
      return PenjualanViewModel(
        ref.watch(salesRepositoryProvider),
        ref.watch(harvestRepositoryProvider),
        autoLoad: canRead,
        userId: user?.id ?? '',
        commands: ref.watch(saleCommandsProvider),
      );
    });

final batchPanenListProvider = Provider.autoDispose<List<BatchPanen>>(
  (ref) =>
      ref.watch(penjualanViewModelProvider.select((state) => state.batches)),
);

final availableBatchPanenProvider = Provider.autoDispose<List<BatchPanen>>(
  (ref) => List.unmodifiable(
    ref.watch(batchPanenListProvider).where((batch) => batch.stokTersedia > 0),
  ),
);
