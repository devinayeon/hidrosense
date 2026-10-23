import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/business_date.dart';
import '../core/formatting.dart';
import '../core/uuid.dart';
import '../data/models/harvest_record.dart';
import '../data/models/sale_record.dart';
import '../data/repositories/harvest_repository.dart';
import '../data/repositories/sales_repository.dart';
import '../data/services/api_client.dart';
import '../models/penjualan_model.dart';
import 'panen_viewmodel.dart';
import 'session_viewmodel.dart';

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
  PenjualanViewModel(this._sales, this._harvests, {bool autoLoad = true})
    : super(const PenjualanState()) {
    if (autoLoad) refresh();
  }

  final SalesRepository _sales;
  final HarvestRepository _harvests;
  Future<void>? _refreshTask;
  int _generation = 0;

  Future<void> fetchPenjualanData() => refresh();

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
          items: List.unmodifiable(records.map(_toItem)),
          batches: _toBatches(harvestResult, records),
          salesLoaded: true,
        );
      } else {
        state = PenjualanState(
          items: List.unmodifiable(records.map(_toItem)),
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

  Future<PenjualanItem> createSale(SalesDraft draft) async {
    final record = await _sales.createSale(draft, generateUuidV4());
    final item = _toItem(record);
    if (mounted) _merge(oldItem: null, newItem: item);
    await refresh(force: true);
    return item;
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
    final record = await _sales.updateSale(
      existing.id,
      draft,
      version,
      generateUuidV4(),
    );
    final item = _toItem(record);
    if (mounted) _merge(oldItem: existing, newItem: item);
    await refresh(force: true);
    return item;
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
    final record = await _sales.updateSaleHeader(
      existing.id,
      draft,
      version,
      generateUuidV4(),
    );
    final item = _toItem(record);
    if (mounted) _merge(oldItem: existing, newItem: item);
    await refresh(force: true);
    return item;
  }

  void _merge({PenjualanItem? oldItem, required PenjualanItem newItem}) {
    final byId = <String, PenjualanItem>{
      for (final item in state.items) item.id: item,
      newItem.id: newItem,
    };
    final items = byId.values.toList()..sort(_compareItems);
    state = PenjualanState(
      items: List.unmodifiable(items),
      batches: _adjustBatches(state.batches, oldItem, newItem),
      salesLoaded: true,
    );
  }

  List<BatchPanen> _adjustBatches(
    List<BatchPanen> batches,
    PenjualanItem? oldItem,
    PenjualanItem newItem,
  ) {
    final deltas = <String, double>{};
    for (final detail in oldItem?.details ?? const <PenjualanLine>[]) {
      deltas[detail.idPanen] = (deltas[detail.idPanen] ?? 0) + detail.jumlahKg;
    }
    for (final detail in newItem.details) {
      deltas[detail.idPanen] = (deltas[detail.idPanen] ?? 0) - detail.jumlahKg;
    }
    return List.unmodifiable(
      batches.map((batch) {
        final delta = deltas[batch.id];
        if (delta == null) return batch;
        final stock = _roundKg(batch.stokTersedia + delta);
        return batch.copyWith(stokTersedia: stock < 0 ? 0 : stock);
      }),
    );
  }

  List<BatchPanen> _toBatches(
    List<HarvestRecord> harvests,
    List<SaleRecord> records,
  ) {
    final sold = <String, BigInt>{};
    for (final record in records) {
      for (final detail in record.details) {
        sold[detail.harvestId] =
            (sold[detail.harvestId] ?? BigInt.zero) + detail.quantity.minor;
      }
    }
    return List.unmodifiable(
      harvests.map((harvest) {
        final remaining =
            harvest.saleable.minor - (sold[harvest.id] ?? BigInt.zero);
        final stock = remaining > BigInt.zero ? remaining : BigInt.zero;
        final date = DateTime.parse(harvest.date);
        return BatchPanen(
          id: harvest.id,
          nama:
              'Panen #${harvest.id} · '
              '${formatTanggalIndo(date, singkat: true)}',
          stokTersedia: _minorToDouble(stock),
          tanggalPanen: harvest.date,
        );
      }),
    );
  }

  PenjualanItem _toItem(SaleRecord record) {
    final lines = List<PenjualanLine>.unmodifiable(
      record.details.map(
        (detail) => PenjualanLine(
          idPanen: detail.harvestId,
          tanggalPanen: detail.harvestDate,
          jumlahKg: _minorToDouble(detail.quantity.minor),
          hargaPerKg: detail.price,
          hargaPerKgWire: detail.priceWire,
          totalHarga: detail.total,
          beratLayak: detail.saleable == null
              ? null
              : _minorToDouble(detail.saleable!.minor),
        ),
      ),
    );
    final quantity = lines.fold(0.0, (sum, line) => sum + line.jumlahKg);
    final date = DateTime.parse(record.date);
    return PenjualanItem(
      id: record.id,
      pembeli: record.buyer,
      tanggal: formatTanggalIndo(date, singkat: true),
      tanggalIso: record.date,
      kuantitas: '${formatAngka(quantity)} Kg',
      totalHarga: lines.fold(0.0, (sum, line) => sum + line.totalHarga),
      status: record.status == 'lunas'
          ? StatusPenjualan.lunas
          : StatusPenjualan.belumLunas,
      catatan: record.note,
      batchPanenId: lines.length == 1 ? lines.first.idPanen : null,
      version: record.version,
      details: lines,
    );
  }

  int _compareItems(PenjualanItem a, PenjualanItem b) {
    final aDate = a.tanggalIso, bDate = b.tanggalIso;
    if (aDate != null && bDate != null) {
      final byDate = bDate.compareTo(aDate);
      if (byDate != 0) return byDate;
    } else if (aDate != null) {
      return -1;
    } else if (bDate != null) {
      return 1;
    }
    final aId = BigInt.tryParse(a.id) ?? BigInt.zero;
    final bId = BigInt.tryParse(b.id) ?? BigInt.zero;
    return bId.compareTo(aId);
  }

  double _minorToDouble(BigInt minor) => minor.toDouble() / 100;

  double _roundKg(double weight) => double.parse(weight.toStringAsFixed(2));
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

final penjualanSearchQueryProvider = StateProvider<String>((ref) => '');

final penjualanFilterCategoryProvider = StateProvider<PenjualanFilterCategory>(
  (ref) => PenjualanFilterCategory.all,
);

final filteredPenjualanListProvider = Provider.autoDispose<List<PenjualanItem>>(
  (ref) {
    final allList = ref.watch(
      penjualanViewModelProvider.select((state) => state.items),
    );
    final query = ref.watch(penjualanSearchQueryProvider).toLowerCase();
    final filter = ref.watch(penjualanFilterCategoryProvider);

    return List.unmodifiable(
      allList.where((item) {
        final matchesSearch =
            item.pembeli.toLowerCase().contains(query) ||
            item.kuantitas.toLowerCase().contains(query);
        final matchesFilter = switch (filter) {
          PenjualanFilterCategory.lunas => item.isLunas,
          PenjualanFilterCategory.belumLunas => !item.isLunas,
          PenjualanFilterCategory.all => true,
        };
        return matchesSearch && matchesFilter;
      }),
    );
  },
);

final totalPendapatanBulanIniProvider = Provider.autoDispose<double>((ref) {
  final list = ref.watch(
    penjualanViewModelProvider.select((state) => state.items),
  );
  final today = jakartaToday(ref.watch(penjualanClockProvider)());
  return list
      .where((item) {
        if (!item.isLunas) return false;
        final date = item.tanggalTransaksi;
        return date != null &&
            date.year == today.year &&
            date.month == today.month;
      })
      .fold(0.0, (sum, item) => sum + item.totalHarga);
});
