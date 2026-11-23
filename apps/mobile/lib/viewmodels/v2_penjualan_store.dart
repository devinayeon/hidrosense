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
import 'v2_damage_sender.dart';
import 'v2_inventory_sender.dart';
import 'v2_nursery_sender.dart';
import 'v2_panen_sender.dart';
import 'v2_penjualan_mappers.dart';
import 'v2_sync_queue.dart';
import 'v2_sync_replayer.dart';

/// Data awal form 11.9 untuk satu baris antrean Penjualan.
class V2PenjualanRepair {
  const V2PenjualanRepair({required this.sale, required this.panen});

  /// Baris yang sudah diisi dari payload antrean.
  final V2Penjualan sale;

  /// Pilihan panen terbaru; form menambahkan berat baris ini sendiri.
  final List<V2PenjualanPanen> panen;
}

/// Menyiapkan dan mengirim ulang penjualan yang ditolak server (11.9).
abstract interface class V2PenjualanRepairer {
  SyncQueueJenis get jenis;

  /// Data form perbaikan; null bila baris tidak bisa diperbaiki dari HP.
  Future<V2PenjualanRepair?> prepare(SyncQueueItem item);

  /// Menulis ulang isian dengan kunci idempoten asli, lalu melepas baris
  /// antrean. Melempar [V2PenjualanStoreException] berpesan siap tampil.
  Future<void> resend(SyncQueueItem item, V2PenjualanDraft draft);
}

/// Store sempit untuk form perbaikan 11.9: hanya [update] yang dipakai, dan
/// tulisannya diteruskan ke pengirim baris antrean dengan kunci aslinya.
class V2PenjualanQueueStore implements V2PenjualanStore {
  V2PenjualanQueueStore(this._repairer, this._item);

  final V2PenjualanRepairer _repairer;
  final SyncQueueItem _item;

  @override
  Future<V2Penjualan> update(
    V2Penjualan existing,
    V2PenjualanDraft draft,
  ) async {
    await _repairer.resend(_item, draft);
    return existing.copyWith(
      pembeli: draft.pembeli,
      tanggal: draft.tanggal,
      jumlahKg: draft.jumlahKg,
      hargaPerKg: draft.hargaPerKg,
      pembayaran: draft.pembayaran,
      sync: V2PenjualanSync.terkirim,
    );
  }

  @override
  Future<V2Penjualan> create(V2PenjualanDraft draft) =>
      throw UnsupportedError('Form perbaikan tidak membuat penjualan baru.');

  @override
  Future<V2PenjualanSnapshot> load() =>
      throw UnsupportedError('Form perbaikan tidak memuat daftar.');

  @override
  Future<V2Penjualan> markPaid(V2Penjualan existing) =>
      throw UnsupportedError('Form perbaikan tidak menandai lunas.');

  @override
  Future<V2Penjualan> reload(V2Penjualan existing) =>
      throw UnsupportedError('Form perbaikan tidak memuat ulang baris.');
}

/// Store penjualan v2 yang memakai API dan aturan tulis v1.
///
/// Semua penulisan lewat [PenjualanViewModel] supaya kunci idempoten,
/// penguncian isian yang belum pasti, dan penyegaran stok tetap satu jalur
/// dengan aplikasi v1. Tulis yang gagal tanpa jawaban pasti dicatat ke
/// [V2SyncQueue] supaya tidak hilang saat aplikasi ditutup, dan bisa dikirim
/// ulang sebagai [V2SyncSender].
class V2PenjualanApiStore
    implements
        V2PenjualanStore,
        V2SyncSender,
        V2SyncConflictResolver,
        V2PenjualanRepairer {
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
    try {
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
    } on ApiException catch (error) {
      // Bentrok versi bukan penolakan biasa: pengguna memilih versi di 11.8.
      if (error.code == 'SALE_VERSION_CONFLICT') {
        throw V2SyncConflictException(error.message);
      }
      rethrow;
    }
  }

  /// Menyiapkan form 11.9 dari payload baris antrean.
  ///
  /// Baris koreksi memakai salinan server terbaru supaya isian lain ikut
  /// benar; baris baru dirangkai dari payload. Null berarti baris tidak lagi
  /// punya panen atau penjualan yang bisa diperbaiki dari HP.
  @override
  Future<V2PenjualanRepair?> prepare(SyncQueueItem item) async {
    await _viewModel.refresh(force: true);
    final batches = _viewModel.current.batches;
    final panen = v2PanenOptions(batches);
    if (item.mode == SyncQueueMode.header) return null;
    if (item.mode == SyncQueueMode.rincian &&
        _existing(item.target) == null) {
      return null;
    }
    final payload = _draftFromPayload(item.payload);
    BatchPanen? batch;
    for (final row in batches) {
      if (row.id == payload.harvestId) batch = row;
    }
    if (batch == null) return null;
    final tanggalPanen = DateTime.tryParse(batch.tanggalPanen ?? '');
    final tanggal = DateTime.tryParse(payload.date);
    if (tanggalPanen == null || tanggal == null) return null;
    final label = 'Panen ${formatTanggalPendek(tanggalPanen)}';
    return V2PenjualanRepair(
      sale: V2Penjualan(
        id: item.target,
        pembeli: payload.buyer,
        tanggal: tanggal,
        jumlahKg: payload.quantity,
        hargaPerKg: payload.price,
        pembayaran: payload.status == 'lunas'
            ? V2PenjualanBayar.lunas
            : V2PenjualanBayar.belumLunas,
        panen: label,
        panenAsal: 'Dari $label',
        panenId: payload.harvestId,
        tanggalPanen: tanggalPanen,
        sync: V2PenjualanSync.antrean,
      ),
      panen: panen,
    );
  }

  /// Mengirim ulang isian perbaikan dengan kunci dan tiket versi asli.
  @override
  Future<void> resend(SyncQueueItem item, V2PenjualanDraft draft) async {
    final panenId = draft.panenId;
    if (panenId == null) {
      throw const V2PenjualanStoreException('Pilih panen dulu.');
    }
    await _viewModel.refresh(force: true);
    final old = item.mode == SyncQueueMode.baru ? null : _existing(item.target);
    final version = item.expectedVersion;
    if (item.mode != SyncQueueMode.baru) {
      if (old == null) {
        throw const V2PenjualanStoreException(
          'Penjualan sudah tidak ada di server.',
        );
      }
      if (version == null) {
        throw const V2PenjualanStoreException(
          'Versi baris tidak tersimpan; perbaiki lewat daftar penjualan.',
        );
      }
    }
    final sales = _saleDraft(draft, panenId);
    try {
      await _viewModel.replayCommand(
        SaleCommand(
          key: item.key,
          target: item.target,
          payload: jsonEncode(sales.toJson()),
          expectedVersion: version,
          draft: sales,
          oldItem: old,
          write: item.mode == SyncQueueMode.baru
              ? (repo, key) => repo.createSale(sales, key)
              : (repo, key) =>
                    repo.updateSale(old!.id, sales, version!, key),
        ),
      );
    } on ApiException catch (error) {
      throw V2PenjualanStoreException(
        error.code == 'SALE_VERSION_CONFLICT'
            ? 'Data sudah berubah di server. Selesaikan lewat dialog konflik.'
            : serviceError(error),
      );
    }
    await queue?.remove(item.key);
  }

  /// Menyelesaikan baris `konflik` menurut pilihan dialog 11.8.
  ///
  /// "Pakai data server" membuang isi HP. "Kirim ulang punya saya" memuat
  /// ulang daftar, memakai versi server terbaru sebagai tiket, lalu menulis
  /// ulang isi HP — tulis terakhir menang tanpa menabrak pemeriksaan versi.
  @override
  Future<void> resolveConflict(
    SyncQueueItem item, {
    required bool useServer,
  }) async {
    final queue = this.queue;
    if (useServer) {
      await queue?.remove(item.key);
      return;
    }
    await _viewModel.refresh(force: true);
    final old = item.mode == SyncQueueMode.baru
        ? null
        : _existing(item.target);
    final version = old?.version;
    if (item.mode != SyncQueueMode.baru &&
        (old == null || version == null)) {
      throw const V2SyncRejectedException(
        'Penjualan sudah tidak ada di server; pakai data server.',
      );
    }
    final draft = item.mode == SyncQueueMode.header
        ? null
        : _draftFromPayload(item.payload);
    final header = item.mode == SyncQueueMode.header
        ? _headerFromPayload(item.payload)
        : null;
    try {
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
            // Penjualan baru tidak punya versi, jadi tidak bisa bentrok.
            SyncQueueMode.baru => (sales, key) => sales.createSale(draft!, key),
            SyncQueueMode.rincian => (sales, key) =>
              sales.updateSale(old!.id, draft!, version!, key),
            SyncQueueMode.header => (sales, key) =>
              sales.updateSaleHeader(old!.id, header!, version!, key),
          },
        ),
      );
    } on ApiException catch (error) {
      if (error.code == 'SALE_VERSION_CONFLICT') {
        throw V2SyncConflictException(error.message);
      }
      rethrow;
    }
    await queue?.remove(item.key);
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

/// Penyelesai konflik versi per jenis data untuk dialog 11.8.
///
/// Penjualan punya penyelesai sendiri di store-nya; panen menumpang
/// pengirimnya. Jenis yang belum punya resolver akan menampilkan pesan
/// "belum bisa diselesaikan dari HP".
final v2SyncResolversProvider = Provider<List<V2SyncConflictResolver>>((ref) {
  final store = ref.watch(v2PenjualanStoreProvider);
  return <V2SyncConflictResolver>[
    if (store is V2SyncConflictResolver) store as V2SyncConflictResolver,
    ref.watch(v2PanenSenderProvider),
  ];
});

/// Pengirim antrean nyata; null bila tidak ada jenis yang bisa dikirim.
///
/// Semua jenis tulis (penjualan, panen, semaian, stok, dan rusak) kini punya
/// pengirim.
final v2SyncReplayerProvider = Provider<V2SyncReplayer?>((ref) {
  final store = ref.watch(v2PenjualanStoreProvider);
  final senders = <V2SyncSender>[
    ?(store is V2SyncSender ? store as V2SyncSender : null),
    ref.watch(v2PanenSenderProvider),
    ref.watch(v2NurserySenderProvider),
    ref.watch(v2InventorySenderProvider),
    ref.watch(v2DamageSenderProvider),
  ];
  return V2SyncReplayer(
    queue: ref.watch(v2SyncQueueProvider.notifier),
    senders: senders,
    resolvers: ref.watch(v2SyncResolversProvider),
  );
});
