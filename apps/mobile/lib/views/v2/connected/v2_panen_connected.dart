import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/business_date.dart';
import '../../../core/formatting.dart';
import '../../../data/models/harvest_draft.dart';
import '../../../data/models/harvest_record.dart';
import '../../../data/models/inventory_record.dart';
import '../../../data/models/nursery_record.dart';
import '../../../data/models/table_record.dart';
import '../../../data/models/transfer_record.dart';
import '../../../viewmodels/connected_inventory_viewmodel.dart';
import '../../../viewmodels/connected_table_viewmodel.dart';
import '../../../viewmodels/panen_viewmodel.dart';
import '../components/v2_panen_data.dart';
import '../pages/v2_panen_detail_page.dart';
import '../pages/v2_panen_form_page.dart';
import '../pages/v2_panen_list_page.dart';
import 'v2_meja_connected.dart';

double _kg(HarvestWeight? weight) =>
    weight == null ? 0 : weight.minor.toDouble() / 100;

String _kodeMeja(TableRecord? table, String fallback) =>
    table?.displayName ?? 'Meja $fallback';

String? _varietasPanen(
  HarvestRecord record,
  List<TransferRecord> transfers,
  List<SowingRecord> sowings,
  List<InventoryRecord> inventaris,
) {
  final detail = record.details.firstOrNull;
  if (detail == null) return null;
  final transfer = transfers
      .where((row) => row.id == detail.transferId)
      .firstOrNull;
  if (transfer == null) return null;
  return v2NamaVarietasTransfer(transfer, sowings, inventaris);
}

/// Satu baris estimasi dari batch yang masih punya tanaman aktif.
V2PanenEstimasi v2PanenEstimasiFromTransfer(
  TransferRecord transfer, {
  TableRecord? table,
  List<SowingRecord> sowings = const <SowingRecord>[],
  List<InventoryRecord> inventaris = const <InventoryRecord>[],
}) {
  final sisa =
      transfer.remainingHarvestDays ??
      (transfer.estimatedHarvestDate == null
          ? 0
          : DateTime.tryParse(
                  transfer.estimatedHarvestDate!,
                )?.difference(jakartaToday()).inDays ??
              0);
  return V2PanenEstimasi(
    meja: _kodeMeja(table, transfer.tableId),
    varietas:
        v2NamaVarietasTransfer(transfer, sowings, inventaris) ?? 'Tanaman meja',
    jumlahTanaman: transfer.activePlants,
    hariLagi: sisa < 0 ? 0 : sisa,
    transferId: transfer.id,
  );
}

/// Pemetaan satu panen backend ke kartu ringkasan page 07.
V2PanenItem v2PanenItemFromRecord(
  HarvestRecord record, {
  List<TransferRecord> transfers = const <TransferRecord>[],
  List<TableRecord> tables = const <TableRecord>[],
  List<SowingRecord> sowings = const <SowingRecord>[],
  List<InventoryRecord> inventaris = const <InventoryRecord>[],
}) {
  final detail = record.details.firstOrNull;
  final table = detail == null
      ? null
      : tables.where((row) => row.id == detail.tableId).firstOrNull;
  return V2PanenItem(
    id: record.id,
    tanggal: DateTime.tryParse(record.date) ?? jakartaToday(),
    meja: table?.displayName ??
        (detail == null ? 'Meja' : 'Meja ${detail.tableCode}'),
    varietas:
        _varietasPanen(record, transfers, sowings, inventaris) ??
        'Tanaman meja',
    jumlahTanaman: record.plantCount,
    beratTotal: _kg(record.total ?? record.saleable),
    beratReject: _kg(record.reject),
    keterangan: record.note,
  );
}

/// Isi segmen "Panen" di tab Tanam dengan data backend.
class V2PanenConnectedTab extends ConsumerWidget {
  const V2PanenConnectedTab({
    super.key,
    this.initialChipIndex = 0,
    this.onSegmentChanged,
  });

  final int initialChipIndex;
  final ValueChanged<int>? onSegmentChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(panenViewModelProvider);
    final transfers = ref.watch(v2AllTransfersProvider).valueOrNull ?? const [];
    final sowings = ref.watch(v2AllSowingsProvider).valueOrNull ?? const [];
    final inventaris = ref.watch(
      connectedInventoryProvider.select((value) => value.activeRecords),
    );
    final tables = ref.watch(connectedTableProvider).records;
    final estimasi = state.transfers
        .where((row) => row.activePlants > 0)
        .map(
          (row) => v2PanenEstimasiFromTransfer(
            row,
            table: tables.where((table) => table.id == row.tableId).firstOrNull,
            sowings: sowings,
            inventaris: inventaris,
          ),
        )
        .toList()
      ..sort((a, b) {
        if (a.siapPanen != b.siapPanen) return a.siapPanen ? -1 : 1;
        return a.hariLagi.compareTo(b.hariLagi);
      });
    final riwayat = state.records
        .map(
          (record) => v2PanenItemFromRecord(
            record,
            transfers: transfers,
            tables: tables,
            sowings: sowings,
            inventaris: inventaris,
          ),
        )
        .toList();
    final viewState = switch (state) {
      PanenState(loading: true) when riwayat.isEmpty && estimasi.isEmpty =>
        V2PanenState.loading,
      PanenState(error: _?) when riwayat.isEmpty && estimasi.isEmpty =>
        V2PanenState.error,
      _ => V2PanenState.ready,
    };
    return V2PanenTabView(
      estimasi: estimasi,
      riwayat: riwayat,
      state: viewState,
      initialChipIndex: initialChipIndex,
      onSegmentChanged: onSegmentChanged,
      onRetry: () => ref.read(panenViewModelProvider.notifier).refresh(),
      onCatatPanen: estimasi.isEmpty
          ? null
          : () => _catatPanen(context, ref, estimasi),
      onTapPanen: (item) => _bukaDetail(context, ref, item),
    );
  }

  Future<void> _catatPanen(
    BuildContext context,
    WidgetRef ref,
    List<V2PanenEstimasi> pilihan,
  ) async {
    final hasil = await Navigator.of(context).push<V2PanenItem>(
      V2PanenFormPage.route(
        pilihan: pilihan,
        initialDate: jakartaToday(),
      ),
    );
    if (hasil == null) return;
    final transferId = hasil.transferId;
    if (transferId == null) {
      if (!context.mounted) return;
      _pesan(context, 'Pilih tanaman dari daftar estimasi.');
      return;
    }
    final result = await ref
        .read(panenViewModelProvider.notifier)
        .submit(
          HarvestDraft(
            date: apiDate(hasil.tanggal),
            note: hasil.keterangan,
            rows: [
              HarvestDraftRow(
                transferId: transferId,
                plantCount: hasil.jumlahTanaman,
                total: formatAngka(hasil.beratTotal),
                reject: formatAngka(hasil.beratReject),
              ),
            ],
          ),
        );
    if (!context.mounted) return;
    switch (result) {
      case HarvestSubmitResult.saved:
      case HarvestSubmitResult.savedRefreshFailed:
        ref.invalidate(v2AllTransfersProvider);
        _pesan(context, 'Panen dicatat.');
      case HarvestSubmitResult.failed:
        _pesan(
          context,
          ref.read(panenViewModelProvider).error ?? 'Panen gagal dicatat.',
        );
      case HarvestSubmitResult.busy:
        _pesan(context, 'Panen sedang disimpan.');
    }
  }

  Future<void> _bukaDetail(
    BuildContext context,
    WidgetRef ref,
    V2PanenItem item,
  ) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => V2PanenConnectedDetailPage(item: item),
      ),
    );
  }
}

void _pesan(BuildContext context, String pesan) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(pesan)));
}

/// Detail panen yang menyimpan koreksi berat ke backend.
class V2PanenConnectedDetailPage extends ConsumerStatefulWidget {
  const V2PanenConnectedDetailPage({super.key, required this.item});

  final V2PanenItem item;

  @override
  ConsumerState<V2PanenConnectedDetailPage> createState() =>
      _V2PanenConnectedDetailPageState();
}

class _V2PanenConnectedDetailPageState
    extends ConsumerState<V2PanenConnectedDetailPage> {
  late V2PanenItem _item = widget.item;

  HarvestRecord? _record() => ref
      .read(panenViewModelProvider)
      .records
      .where((record) => record.id == _item.id)
      .firstOrNull;

  Future<V2PanenItem> _simpan(V2PanenItem edited) async {
    final record = _record();
    if (record == null) throw StateError('Panen belum termuat.');
    final version = record.version;
    if (version == null) {
      throw StateError('Versi panen tidak tersedia. Muat ulang daftar.');
    }
    if (record.details.length != 1) {
      throw StateError(
        'Koreksi panen dengan beberapa rincian belum didukung layar ini.',
      );
    }
    final detail = record.details.first;
    final result = await ref
        .read(panenViewModelProvider.notifier)
        .correct(
          HarvestCorrection(
            id: record.id,
            expectedVersion: version,
            note: edited.keterangan,
            rows: [
              HarvestCorrectionRow(
                detailId: detail.id,
                total: formatAngka(edited.beratTotal),
                reject: formatAngka(edited.beratReject),
              ),
            ],
          ),
        );
    if (result == HarvestSubmitResult.busy) {
      throw StateError('Panen sedang disimpan.');
    }
    if (result == HarvestSubmitResult.failed) {
      throw StateError(
        ref.read(panenViewModelProvider).error ?? 'Koreksi panen gagal.',
      );
    }
    final terbaru = _record();
    if (terbaru == null) return edited;
    final tables = ref.read(connectedTableProvider).records;
    final transfers = ref.read(v2AllTransfersProvider).valueOrNull ?? const [];
    final sowings = ref.read(v2AllSowingsProvider).valueOrNull ?? const [];
    final inventaris = ref
        .read(connectedInventoryProvider)
        .activeRecords;
    final hasil = v2PanenItemFromRecord(
      terbaru,
      transfers: transfers,
      tables: tables,
      sowings: sowings,
      inventaris: inventaris,
    );
    if (mounted) setState(() => _item = hasil);
    return hasil;
  }

  @override
  Widget build(BuildContext context) {
    return V2PanenDetailPage(item: _item, onUbah: _simpan);
  }
}