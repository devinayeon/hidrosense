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
import '../../../models/penjualan_model.dart';
import '../../../viewmodels/connected_inventory_viewmodel.dart';
import '../../../viewmodels/connected_table_viewmodel.dart';
import '../../../viewmodels/panen_viewmodel.dart';
import '../../../viewmodels/penjualan_viewmodel.dart';
import '../../../viewmodels/v2_penjualan_store.dart';
import '../components/v2_panen_data.dart';
import '../components/v2_penjualan_data.dart';
import '../pages/v2_panen_detail_page.dart';
import '../pages/v2_panen_form_page.dart';
import '../pages/v2_panen_list_page.dart';
import '../pages/v2_penjualan_form_page.dart';
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
    transferDate: DateTime.tryParse(transfer.transferDate),
    hss: transfer.hss ?? transfer.seedlingAgeDays,
    sowingLabel: _labelSemaian(transfer.sowingId),
  );
}

/// `Batch #12` untuk asal semaian baris pemilih panen (BUG-33).
String _labelSemaian(String sowingId) => 'Batch #$sowingId';

/// Daftar estimasi panen siap dipilih: hanya batch bertanaman aktif, tanpa
/// baris ganda (id pemindahan sama muncul sekali), lalu diurutkan siap panen
/// lebih dulu dan HSS/hari menuju panen paling dekat di atas (BUG-33).
List<V2PanenEstimasi> v2DaftarEstimasiPanen({
  required List<TransferRecord> transfers,
  required List<TableRecord> tables,
  List<SowingRecord> sowings = const <SowingRecord>[],
  List<InventoryRecord> inventaris = const <InventoryRecord>[],
}) {
  final hasil = <V2PanenEstimasi>[];
  final terlihat = <String>{};
  for (final row in transfers) {
    if (row.activePlants <= 0) continue;
    final item = v2PanenEstimasiFromTransfer(
      row,
      table: tables.where((table) => table.id == row.tableId).firstOrNull,
      sowings: sowings,
      inventaris: inventaris,
    );
    if (!terlihat.add(item.kunci)) continue;
    hasil.add(item);
  }
  hasil.sort((a, b) {
    if (a.siapPanen != b.siapPanen) return a.siapPanen ? -1 : 1;
    return a.hariLagi.compareTo(b.hariLagi);
  });
  return hasil;
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
    rincian: _rincianPanen(record, tables),
  );
}

/// Rincian per batch untuk koreksi "Ubah panen" (frame 7.19).
///
/// Panen yang belum disortasi tidak punya `berat_total`; berat layak dipakai
/// sebagai isian awal supaya koreksi tetap bisa disimpan.
List<V2PanenRincian> _rincianPanen(
  HarvestRecord record,
  List<TableRecord> tables,
) => [
  for (final baris in record.details)
    V2PanenRincian(
      detailId: baris.id,
      label: _kodeMeja(
        tables.where((row) => row.id == baris.tableId).firstOrNull,
        baris.tableCode,
      ),
      beratTotal: _kg(baris.total ?? baris.saleable),
      beratReject: _kg(baris.reject),
    ),
];

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
    final sowings = ref.watch(v2AllSowingsProvider).valueOrNull ?? const [];
    final inventaris = ref.watch(
      connectedInventoryProvider.select((value) => value.activeRecords),
    );
    final tables = ref.watch(connectedTableProvider).records;
    final estimasi = v2DaftarEstimasiPanen(
      transfers: state.transfers,
      tables: tables,
      sowings: sowings,
      inventaris: inventaris,
    );
    final riwayat = state.records
        .map(
          (record) => v2PanenItemFromRecord(
            record,
            // Batch sudah dimuat VM panen; tidak perlu mengambil ulang lewat
            // provider meja (menghindari daftar pemindahan ganda).
            transfers: state.transfers,
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
      estimasiLoading: !state.transfersLoaded,
      riwayatLoading: !state.recordsLoaded,
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
        onSubmit: (hasil) async {
          final transferId = hasil.transferId;
          if (transferId == null) {
            throw StateError('Pilih tanaman dari daftar estimasi.');
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
          switch (result) {
            case HarvestSubmitResult.saved:
            case HarvestSubmitResult.savedRefreshFailed:
              ref.invalidate(v2AllTransfersProvider);
            case HarvestSubmitResult.failed:
              throw StateError(
                ref.read(panenViewModelProvider).error ??
                    'Panen gagal dicatat.',
              );
            case HarvestSubmitResult.busy:
              throw StateError('Panen sedang disimpan.');
          }
        },
      ),
    );
    if (!context.mounted || hasil == null) return;
    _pesan(context, 'Panen dicatat.');
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

/// Berat terjual satu panen dari stok batch penjualan yang sudah dimuat.
///
/// Endpoint panen tidak mengembalikan angka terjual, jadi dihitung dari
/// `stokTersedia` batch (`BatchPanen` = berat layak − terjual). BUG-43.
double v2TerjualDariBatch(
  HarvestRecord record,
  List<BatchPanen> batches,
) {
  final batch = batches.where((row) => row.id == record.id).firstOrNull;
  if (batch == null) return 0;
  final terjual = _kg(record.saleable) - batch.stokTersedia;
  return terjual > 0 ? terjual : 0;
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
    // Satu baris koreksi per rincian, dikirim dengan `id_detail_panen` masing
    // masing (batas backend 100 rincian per panen).
    final rows = edited.rincian.isEmpty
        ? [
            for (final baris in record.details)
              HarvestCorrectionRow(
                detailId: baris.id,
                total: formatAngka(_kg(baris.total ?? baris.saleable)),
                reject: formatAngka(_kg(baris.reject)),
              ),
          ]
        : [
            for (final baris in edited.rincian)
              HarvestCorrectionRow(
                detailId: baris.detailId,
                total: formatAngka(baris.beratTotal),
                reject: formatAngka(baris.beratReject),
              ),
          ];
    final result = await ref
        .read(panenViewModelProvider.notifier)
        .correct(
          HarvestCorrection(
            id: record.id,
            expectedVersion: version,
            note: edited.keterangan,
            rows: rows,
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
    final transfers = ref.read(panenViewModelProvider).transfers;
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

  /// Hitung ulang berat terjual dari stok batch penjualan yang sudah dimuat.
  ///
  /// Endpoint panen tidak mengembalikan angka terjual, jadi sisa dihitung dari
  /// `stokTersedia` batch (berat layak − terjual). Dengan begitu Detail panen
  /// ikut berubah setelah penjualan tersimpan (BUG-43).
  V2PanenItem _denganTerjual(V2PanenItem item) {
    final record = _record();
    if (record == null) return item;
    final batches = ref.watch(
      penjualanViewModelProvider.select((state) => state.batches),
    );
    return item.copyWith(terjual: v2TerjualDariBatch(record, batches));
  }

  /// Catat penjualan dari Detail panen lewat backend nyata (BUG-42): tanggal
  /// bawaan hari ini WIB (bukan 15 Nov contoh) dan simpan benar-benar menulis.
  Future<void> _catatPenjualan() async {
    final store = ref.read(v2PenjualanStoreProvider);
    if (store == null) {
      _pesan(context, 'Tidak punya akses mencatat penjualan.');
      return;
    }
    final item = _denganTerjual(_item);
    final hasil = await Navigator.of(context).push<V2Penjualan>(
      V2PenjualanFormPage.route(
        panen: <V2PenjualanPanen>[
          V2PenjualanPanen(
            id: item.id,
            tanggalPanen: item.tanggal,
            sisaKg: item.sisa,
          ),
        ],
        store: store,
        initialDate: jakartaToday(),
      ),
    );
    if (!mounted || hasil == null) return;
    // Penjualan mengurangi stok batch; provider penjualan sudah dimuat ulang
    // oleh store, jadi cukup bangun ulang supaya sisa/terjual ikut berubah.
    setState(() {});
    _pesan(context, 'Penjualan dicatat.');
  }

  @override
  Widget build(BuildContext context) {
    // Jaga viewmodel panen tetap hidup selama halaman terbuka (autoDispose) dan
    // bangun ulang saat daftar panen berubah.
    ref.watch(panenViewModelProvider.select((state) => state.records));
    return V2PanenDetailPage(
      item: _denganTerjual(_item),
      onUbah: _simpan,
      onCatatPenjualan: _catatPenjualan,
    );
  }
}