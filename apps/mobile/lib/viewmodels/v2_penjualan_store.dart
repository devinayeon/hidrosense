import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/business_date.dart';
import '../data/models/sale_record.dart';
import '../data/services/api_client.dart';
import '../models/penjualan_model.dart';
import '../views/v2/components/v2_penjualan_data.dart';
import '../views/v2/components/v2_penjualan_store.dart';
import 'penjualan_viewmodel.dart';
import 'session_viewmodel.dart';
import 'v2_penjualan_mappers.dart';

/// Store penjualan v2 yang memakai API dan aturan tulis v1.
///
/// Semua penulisan lewat [PenjualanViewModel] supaya kunci idempoten,
/// penguncian isian yang belum pasti, dan penyegaran stok tetap satu jalur
/// dengan aplikasi v1.
class V2PenjualanApiStore implements V2PenjualanStore {
  V2PenjualanApiStore(this._viewModel);

  final PenjualanViewModel _viewModel;

  @override
  Future<V2PenjualanSnapshot> load() async {
    await _viewModel.refresh(force: true);
    final state = _viewModel.current;
    if (state.items.isEmpty && state.error != null) {
      throw V2PenjualanStoreException(state.error!);
    }
    return V2PenjualanSnapshot(
      items: List.unmodifiable([
        for (final item in state.items)
          v2PenjualanFromItem(item, state.batches),
      ]),
      panen: v2PanenOptions(state.batches),
    );
  }

  @override
  Future<V2Penjualan> create(V2PenjualanDraft draft) async {
    final panenId = draft.panenId;
    if (panenId == null) {
      throw const V2PenjualanStoreException('Pilih panen dulu.');
    }
    return _write(() async {
      final item = await _viewModel.createSale(
        _saleDraft(draft, panenId),
      );
      return v2PenjualanFromItem(item, _viewModel.current.batches);
    });
  }

  @override
  Future<V2Penjualan> update(
    V2Penjualan existing,
    V2PenjualanDraft draft,
  ) async {
    return _write(() async {
      final item = _itemOf(existing.id);
      final panenId = draft.panenId;
      final detailsChanged =
          panenId != existing.panenId ||
          (draft.jumlahKg - existing.jumlahKg).abs() > 0.001 ||
          (draft.hargaPerKg - existing.hargaPerKg).abs() > 0.001;

      if (item.details.length != 1) {
        if (detailsChanged) {
          throw const V2PenjualanStoreException(
            'Penjualan ini berisi beberapa panen. Jumlah dan harga belum bisa '
            'diubah dari aplikasi.',
          );
        }
        final updated = await _viewModel.updateSaleHeader(
          item,
          SalesHeaderDraft(
            date: apiDate(draft.tanggal),
            buyer: draft.pembeli,
            status: _statusWire(draft.pembayaran),
          ),
        );
        return v2PenjualanFromItem(updated, _viewModel.current.batches);
      }

      final updated = await _viewModel.updateSale(
        item,
        _saleDraft(draft, panenId ?? item.details.single.idPanen),
      );
      return v2PenjualanFromItem(updated, _viewModel.current.batches);
    });
  }

  @override
  Future<V2Penjualan> markPaid(V2Penjualan existing) async {
    return _write(() async {
      final item = _itemOf(existing.id);
      final updated = await _viewModel.updateSaleHeader(
        item,
        SalesHeaderDraft(
          date: apiDate(existing.tanggal),
          buyer: existing.pembeli,
          status: 'lunas',
        ),
      );
      return v2PenjualanFromItem(updated, _viewModel.current.batches);
    });
  }

  @override
  Future<V2Penjualan> reload(V2Penjualan existing) {
    return _write(() async {
      await _viewModel.refresh(force: true);
      final state = _viewModel.current;
      for (final item in state.items) {
        if (item.id == existing.id) {
          return v2PenjualanFromItem(item, state.batches);
        }
      }
      throw const V2PenjualanStoreException(
        'Penjualan sudah tidak ada di server. Muat ulang daftar.',
      );
    });
  }

  PenjualanItem _itemOf(String id) {
    for (final item in _viewModel.current.items) {
      if (item.id == id) return item;
    }
    throw const V2PenjualanStoreException(
      'Penjualan tidak ditemukan. Muat ulang daftar.',
    );
  }

  SalesDraft _saleDraft(V2PenjualanDraft draft, String panenId) {
    return SalesDraft(
      date: apiDate(draft.tanggal),
      buyer: draft.pembeli,
      status: _statusWire(draft.pembayaran),
      harvestId: panenId,
      quantity: draft.jumlahKg,
      price: draft.hargaPerKg,
    );
  }

  String _statusWire(V2PenjualanBayar pembayaran) =>
      pembayaran == V2PenjualanBayar.lunas ? 'lunas' : 'belum_lunas';

  Future<V2Penjualan> _write(Future<V2Penjualan> Function() task) async {
    try {
      return await task();
    } on V2PenjualanStoreException {
      rethrow;
    } on ApiException catch (error) {
      if (error.code == 'SALE_VERSION_CONFLICT') {
        throw const V2PenjualanConflictException();
      }
      throw V2PenjualanStoreException(serviceError(error));
    } catch (error) {
      throw V2PenjualanStoreException(serviceError(error));
    }
  }
}

/// Store untuk alur v2; null berarti pengguna tidak boleh membaca penjualan.
final v2PenjualanStoreProvider = Provider<V2PenjualanStore?>((ref) {
  final user = ref.watch(sessionProvider.select((state) => state.user));
  if (user == null || !user.permissions.contains('penjualan:read')) {
    return null;
  }
  return V2PenjualanApiStore(ref.watch(penjualanViewModelProvider.notifier));
});