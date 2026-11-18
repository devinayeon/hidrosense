import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/business_date.dart';
import '../../../core/uuid.dart';
import '../../../data/models/inventory_record.dart';
import '../../../data/models/nursery_record.dart';
import '../../../data/models/table_record.dart';
import '../../../data/models/transfer_record.dart';
import '../../../viewmodels/connected_inventory_viewmodel.dart';
import '../../../viewmodels/connected_nursery_viewmodel.dart';
import '../../../viewmodels/connected_table_viewmodel.dart';
import '../../../viewmodels/panen_viewmodel.dart';
import '../../../viewmodels/session_viewmodel.dart';
import '../components/v2_meja_data.dart';
import '../components/v2_semaian_data.dart';
import '../pages/v2_meja_detail_page.dart';
import '../pages/v2_meja_form_page.dart';
import '../pages/v2_meja_list_page.dart';
import '../pages/v2_pilih_semaian_page.dart';
import 'v2_semaian_connected.dart';

/// Seluruh batch pemindahan, dipakai meja dan panen untuk membaca tanaman.
///
/// Gagal baca diperlakukan sebagai daftar kosong: daftar meja tetap tampil
/// walau pengguna tidak punya izin batch, hanya tanpa rincian tanaman.
final v2AllTransfersProvider = FutureProvider.autoDispose<List<TransferRecord>>(
  (ref) async {
    final user = ref.watch(sessionProvider.select((state) => state.user));
    if (user == null) return const <TransferRecord>[];
    try {
      return await ref.watch(harvestRepositoryProvider).listTransfers();
    } catch (_) {
      return const <TransferRecord>[];
    }
  },
);

/// Seluruh penyemaian untuk menerjemahkan batch menjadi nama benih.
final v2AllSowingsProvider = FutureProvider.autoDispose<List<SowingRecord>>(
  (ref) async {
    final user = ref.watch(sessionProvider.select((state) => state.user));
    if (user == null) return const <SowingRecord>[];
    try {
      return await ref.watch(nurseryRepositoryProvider).listSowings();
    } catch (_) {
      return const <SowingRecord>[];
    }
  },
);

/// `tersedia`/`penuh`/`pemeliharaan` backend → tiga keadaan desain page 06.
V2MejaStatus v2StatusMeja(TableRecord record) {
  if (record.isMaintenance || record.isInactive) return V2MejaStatus.perawatan;
  if (record.isFull) return V2MejaStatus.penuh;
  return V2MejaStatus.tersedia;
}

String? v2NamaVarietasTransfer(
  TransferRecord transfer,
  List<SowingRecord> sowings,
  List<InventoryRecord> inventaris,
) {
  final sowing = sowings
      .where((item) => item.id == transfer.sowingId)
      .firstOrNull;
  final material = sowing?.materials.firstOrNull;
  if (material == null) return null;
  final bahan = inventaris
      .where((item) => item.id == material.inventoryId)
      .firstOrNull;
  return bahan == null ? null : v2NamaBenih(bahan.name);
}

V2TanamanItem _tanamanFromTransfer(
  TransferRecord transfer, {
  required List<SowingRecord> sowings,
  required List<InventoryRecord> inventaris,
}) {
  final pindah = DateTime.tryParse(transfer.transferDate) ?? jakartaToday();
  final panen =
      DateTime.tryParse(transfer.estimatedHarvestDate ?? '') ??
      DateTime(pindah.year, pindah.month, pindah.day + v2MejaUmurPanenHst);
  return V2TanamanItem(
    varietas:
        v2NamaVarietasTransfer(transfer, sowings, inventaris) ?? 'Tanaman meja',
    tanggalTanam: pindah,
    tanggalPanen: panen,
    tanggalPindah: pindah,
    umurPanenHst:
        transfer.remainingHarvestDays == null || transfer.hst == null
        ? v2MejaUmurPanenHst
        : transfer.remainingHarvestDays! + transfer.hst!,
    hssPindah: transfer.hss ?? v2SemaianHssSiapPindah,
    jumlahAktif: transfer.activePlants,
    jumlahAwal: transfer.plantCount,
    keterangan: transfer.note,
  );
}

/// Pemetaan satu meja backend ke model daftar/detail page 06.
V2MejaItem v2MejaItemFromRecord(
  TableRecord record, {
  List<TransferRecord> transfers = const <TransferRecord>[],
  List<SowingRecord> sowings = const <SowingRecord>[],
  List<InventoryRecord> inventaris = const <InventoryRecord>[],
}) {
  final tanaman = transfers
      .where((item) => item.tableId == record.id && item.activePlants > 0)
      .map(
        (item) => _tanamanFromTransfer(
          item,
          sowings: sowings,
          inventaris: inventaris,
        ),
      )
      .toList();
  return V2MejaItem(
    id: record.id,
    kode: record.code,
    jumlahLubang: record.holeCount,
    terisi: record.activePlants,
    status: v2StatusMeja(record),
    keterangan: record.notes,
    tanaman: tanaman,
  );
}

/// Isi segmen "Meja" di tab Tanam dengan data backend.
class V2MejaConnectedTab extends ConsumerWidget {
  const V2MejaConnectedTab({
    super.key,
    this.initialStatusIndex = 0,
    this.onSegmentChanged,
  });

  final int initialStatusIndex;
  final ValueChanged<int>? onSegmentChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(connectedTableProvider);
    final transfers = ref.watch(v2AllTransfersProvider).valueOrNull ?? const [];
    final sowings = ref.watch(v2AllSowingsProvider).valueOrNull ?? const [];
    final inventaris = ref.watch(
      connectedInventoryProvider.select((value) => value.activeRecords),
    );
    final items = data.records
        .map(
          (record) => v2MejaItemFromRecord(
            record,
            transfers: transfers,
            sowings: sowings,
            inventaris: inventaris,
          ),
        )
        .toList();
    final viewState = switch (data) {
      TableState(loading: true) when items.isEmpty => V2MejaState.loading,
      TableState(error: _?) when items.isEmpty => V2MejaState.error,
      _ => V2MejaState.ready,
    };
    return V2MejaTabView(
      items: items,
      state: viewState,
      initialStatusIndex: initialStatusIndex,
      onSegmentChanged: onSegmentChanged,
      onRetry: () => ref.read(connectedTableProvider.notifier).refresh(),
      onAdd: () => _tambah(context, ref),
      onTapItem: (item) => _bukaDetail(context, ref, item),
    );
  }

  Future<void> _tambah(BuildContext context, WidgetRef ref) async {
    final result = await Navigator.of(
      context,
    ).push<V2MejaItem>(V2MejaFormPage.route());
    if (result == null) return;
    try {
      await ref
          .read(connectedTableProvider.notifier)
          .createTable(
            code: result.kode,
            holeCount: result.jumlahLubang,
            notes: result.keterangan,
          );
      if (!context.mounted) return;
      _pesan(context, 'Meja ditambahkan.');
    } catch (error) {
      if (!context.mounted) return;
      _pesan(context, serviceError(error));
    }
  }

  Future<void> _bukaDetail(
    BuildContext context,
    WidgetRef ref,
    V2MejaItem item,
  ) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => V2MejaConnectedDetailPage(item: item),
      ),
    );
  }
}

void _pesan(BuildContext context, String pesan) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(pesan)));
}

/// Detail meja yang mengubah status/ukuran dan menambah tanaman ke backend.
class V2MejaConnectedDetailPage extends ConsumerStatefulWidget {
  const V2MejaConnectedDetailPage({super.key, required this.item});

  final V2MejaItem item;

  @override
  ConsumerState<V2MejaConnectedDetailPage> createState() =>
      _V2MejaConnectedDetailPageState();
}

class _V2MejaConnectedDetailPageState
    extends ConsumerState<V2MejaConnectedDetailPage> {
  late V2MejaItem _item = widget.item;

  List<InventoryRecord> get _inventaris =>
      ref.read(connectedInventoryProvider).activeRecords;

  V2MejaItem? _dariBackend() {
    final record = ref
        .read(connectedTableProvider)
        .records
        .where((row) => row.id == _item.id)
        .firstOrNull;
    if (record == null) return null;
    return v2MejaItemFromRecord(
      record,
      transfers: ref.read(v2AllTransfersProvider).valueOrNull ?? const [],
      sowings: ref.read(v2AllSowingsProvider).valueOrNull ?? const [],
      inventaris: _inventaris,
    );
  }

  Future<void> _ubahStatus(V2MejaStatus status) async {
    final id = _item.id;
    if (id == null) throw StateError('Meja belum tersimpan di server.');
    await ref
        .read(connectedTableProvider.notifier)
        .updateTable(
          id,
          status: switch (status) {
            V2MejaStatus.tersedia => 'tersedia',
            V2MejaStatus.penuh => 'penuh',
            V2MejaStatus.perawatan => 'pemeliharaan',
          },
        );
    _segarkan();
  }

  Future<void> _ubahMeja(V2MejaItem meja) async {
    final id = _item.id;
    if (id == null) throw StateError('Meja belum tersimpan di server.');
    await ref
        .read(connectedTableProvider.notifier)
        .updateTable(
          id,
          code: meja.kode,
          holeCount: meja.jumlahLubang,
          notes: meja.keterangan,
        );
    _segarkan();
  }

  Future<V2MejaItem?> _tambahTanaman() async {
    final id = _item.id;
    if (id == null) throw StateError('Meja belum tersimpan di server.');
    final siap = (ref.read(v2AllSowingsProvider).valueOrNull ?? const [])
        .where((row) => row.canTransfer)
        .map(
          (row) => v2SemaianItemFromRecord(row, inventaris: _inventaris),
        )
        .toList();
    final pilihan = await Navigator.of(context).push<V2SemaianItem>(
      MaterialPageRoute<V2SemaianItem>(
        builder: (_) => V2PilihSemaianPage(items: siap),
      ),
    );
    if (!mounted || pilihan == null) return null;
    final jumlah = pilihan.jumlahBenih < _item.kosong
        ? pilihan.jumlahBenih
        : _item.kosong;
    await ref
        .read(nurseryRepositoryProvider)
        .transferSowing(
          idempotencyKey: generateUuidV4(),
          sowingId: pilihan.id,
          tableId: id,
          transferDate: apiDate(jakartaToday()),
          plantCount: jumlah,
        );
    await ref.read(connectedTableProvider.notifier).refreshTable(id);
    ref.invalidate(v2AllTransfersProvider);
    ref.invalidate(v2AllSowingsProvider);
    await ref.read(connectedInventoryProvider.notifier).refresh();
    if (!mounted) return null;
    final hasil = _dariBackend() ?? _item.copyWith();
    setState(() => _item = hasil);
    _pesan(context, 'Tanaman ditambahkan.');
    return hasil;
  }

  void _segarkan() {
    final terbaru = _dariBackend();
    if (terbaru != null && mounted) setState(() => _item = terbaru);
  }

  @override
  Widget build(BuildContext context) {
    return V2MejaDetailPage(
      item: _item,
      onUbahStatus: _ubahStatus,
      onUbahMeja: _ubahMeja,
      onTambahTanaman: _tambahTanaman,
    );
  }
}