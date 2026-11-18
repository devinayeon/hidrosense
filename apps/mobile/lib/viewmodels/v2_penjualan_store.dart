import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/business_date.dart';
import '../data/models/sale_record.dart';
import '../data/models/sync_queue_item.dart';
import '../data/services/api_client.dart';
import '../models/penjualan_model.dart';
import '../views/v2/components/v2_penjualan_data.dart';
import '../views/v2/components/v2_penjualan_store.dart';
import 'penjualan_viewmodel.dart';
import 'sale_command.dart';
import 'session_viewmodel.dart';
import 'v2_penjualan_mappers.dart';
import 'v2_sync_queue.dart';
import 'v2_sync_replayer.dart';

/// Store penjualan v2 yang memakai API dan aturan tulis v1.
///
/// Semua penulisan lewat [PenjualanViewModel] supaya kunci idempoten,
/// penguncian isian yang belum pasti, dan penyegaran stok tetap satu jalur
/// dengan aplikasi v1. Tulis yang gagal tanpa jawaban pasti dicatat ke
/// [V2SyncQueue] supaya tidak hilang saat aplikasi ditutup, dan bisa dikirim
/// ulang sebagai [V2SyncSender].
class V2PenjualanApiStore implements V2PenjualanStore, V2SyncSender {
  V2PenjualanApiStore(this._viewModel, {this.queue});

  final PenjualanViewModel _viewModel;

  /// Antrean HP untuk tulis yang belum pasti; null berarti tidak mencatat.
  final V2SyncQueue? queue;

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

  @override
  SyncQueueJenis get jenis => SyncQueueJenis.penjualan;

  /// Mengirim ulang satu baris antrean dengan kunci dan tiket versi aslinya.
  ///
  /// Daftar dimuat ulang dulu supaya baris lama (untuk koreksi) dan stok panen
  /// terbaru tersedia. Kesalahan diteruskan apa adanya — termasuk [ApiException]
  /// — supaya pengirim bisa membedakan penolakan pasti dari kegagalan jaringan.
  @override
  Future<void> send(SyncQueueItem item) async {
    await _viewModel.refresh(force: true);
    final version = item.expectedVersion;
    final old = item.mode == SyncQueueMode.baru ? null : _existing(item.target);
    if (item.mode != SyncQueueMode.baru) {
      if (old == null) {
        throw const V2SyncRejectedException(
          'Penjualan sudah tidak ada di server.',
        );
      }
      if (version == null) {
        throw const V2SyncRejectedException(
          'Versi baris tidak tersimpan; perbaiki lewat daftar penjualan.',
        );
      }
    }
    final draft = item.mode == SyncQueueMode.header
        ? null
        : _draftFromPayload(item.payload);
    final header = item.mode == SyncQueueMode.header
        ? _headerFromPayload(item.payload)
        : null;
    await _viewModel.replayCommand(
      SaleCommand(
        key: item.key,
        target: item.target,
        payload: item.payload,
        expectedVersion: version,
        draft: draft,
        headerDraft: header,
        oldItem: old,
        write: switch (item.mode) {
          SyncQueueMode.baru => (sales, key) => sales.createSale(draft!, key),
          SyncQueueMode.rincian => (sales, key) =>
            sales.updateSale(old!.id, draft!, version!, key),
          SyncQueueMode.header => (sales, key) =>
            sales.updateSaleHeader(old!.id, header!, version!, key),
        },
      ),
    );
  }

  /// Baris server milik [id]; null kalau sudah tidak ada di daftar terbaru.
  PenjualanItem? _existing(String id) {
    for (final item in _viewModel.current.items) {
      if (item.id == id) return item;
    }
    return null;
  }

  SalesDraft _draftFromPayload(String payload) {
    final json = jsonDecode(payload) as Map<String, dynamic>;
    final price = json['harga_per_kg'] as String;
    return SalesDraft(
      date: json['tanggal_penjualan'] as String,
      buyer: json['pembeli'] as String,
      status: json['status_pembayaran'] as String,
      harvestId: json['id_panen'].toString(),
      quantity: double.parse(json['jumlah_kg'] as String),
      price: double.parse(price),
      note: json['keterangan'] as String?,
      priceWireInput: price,
    );
  }

  SalesHeaderDraft _headerFromPayload(String payload) {
    final json = jsonDecode(payload) as Map<String, dynamic>;
    return SalesHeaderDraft(
      date: json['tanggal_penjualan'] as String,
      buyer: json['pembeli'] as String,
      status: json['status_pembayaran'] as String,
      note: json['keterangan'] as String?,
    );
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
      await _queuePending();
      throw V2PenjualanStoreException(serviceError(error));
    } catch (error) {
      await _queuePending();
      throw V2PenjualanStoreException(serviceError(error));
    }
  }

  /// Mencatat tulis yang hasilnya belum pasti ke antrean HP.
  ///
  /// Hanya perintah yang masih tertahan (`uncertainCommand`) yang dicatat:
  /// penolakan 4xx sudah pasti tidak tersimpan, jadi tidak perlu dikirim ulang.
  Future<void> _queuePending() async {
    final queue = this.queue;
    if (queue == null) return;
    final command = _viewModel.uncertainCommand;
    if (command == null) return;
    await queue.record(
      SyncQueueItem(
        key: command.key,
        jenis: SyncQueueJenis.penjualan,
        subtitle: _buyerOf(command),
        mode: _modeOf(command),
        target: command.target,
        payload: command.payload,
        expectedVersion: command.expectedVersion,
        createdAt: DateTime.now(),
      ),
    );
  }

  SyncQueueMode _modeOf(SaleCommand command) => command.headerDraft != null
      ? SyncQueueMode.header
      : command.target == saleCreateTarget
      ? SyncQueueMode.baru
      : SyncQueueMode.rincian;

  String _buyerOf(SaleCommand command) {
    final buyer = command.draft?.buyer ?? command.headerDraft?.buyer ?? '';
    return buyer.isEmpty ? 'Penjualan' : buyer;
  }
}

/// Store untuk alur v2; null berarti pengguna tidak boleh membaca penjualan.
final v2PenjualanStoreProvider = Provider<V2PenjualanStore?>((ref) {
  final user = ref.watch(sessionProvider.select((state) => state.user));
  if (user == null || !user.permissions.contains('penjualan:read')) {
    return null;
  }
  return V2PenjualanApiStore(
    ref.watch(penjualanViewModelProvider.notifier),
    queue: ref.watch(v2SyncQueueProvider.notifier),
  );
});

/// Pengirim antrean nyata; null bila tidak ada jenis yang bisa dikirim.
///
/// Hanya penjualan yang punya pengirim saat ini; jenis lain tetap menunggu di
/// antrean sampai alurnya disambungkan.
final v2SyncReplayerProvider = Provider<V2SyncReplayer?>((ref) {
  final store = ref.watch(v2PenjualanStoreProvider);
  if (store is! V2SyncSender) return null;
  return V2SyncReplayer(
    queue: ref.watch(v2SyncQueueProvider.notifier),
    senders: [store as V2SyncSender],
  );
});