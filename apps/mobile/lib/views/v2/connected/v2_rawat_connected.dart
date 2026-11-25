import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/damage_record.dart';
import '../../../data/models/table_record.dart';
import '../../../viewmodels/connected_table_viewmodel.dart';
import '../../../features/pest/data/pest_models.dart';
import '../../../features/pest/presentation/pages/pest_scan_page.dart';
import '../../../features/pest/presentation/pages/rotation_history_page.dart';
import '../../../features/pest/presentation/viewmodels/pest_history_viewmodel.dart';
import '../../../features/pest/presentation/viewmodels/pest_providers.dart';
import '../../../viewmodels/damage_viewmodel.dart';
import '../components/v2_rawat_data.dart';
import '../pages/v2_pindai_detail_page.dart';
import '../pages/v2_rawat_detail_page.dart';
import '../pages/v2_rawat_list_page.dart';
import 'v2_cuaca_connected.dart';

/// Satu laporan kerusakan backend → baris riwayat tab Rawat.
///
/// Backend hanya menyimpan jenis kerusakan dan jumlah tanaman; tidak ada
/// perawatan, obat, atau foto. Karena itu `meta`/`extra` diisi apa adanya dan
/// kartu detail memakai [V2RawatDetailPage] tanpa kartu foto AI.
V2RawatItem v2RawatItemFromDamage(
  DamageRecord damage,
  TableRecord table,
) {
  final catatan = damage.note?.trim();
  return V2RawatItem(
    id: damage.id,
    hama: damage.category,
    meja: table.displayName,
    tanggal: DateTime.tryParse(damage.date) ?? jakartaToday(),
    meta: '${damage.plantCount} tanaman',
    extra: catatan == null || catatan.isEmpty
        ? 'Laporan kerusakan tanaman.'
        : catatan,
  );
}

/// Satu foto pindaian server → baris “Pindaian terbaru” di tab Rawat.
///
/// Judul berisi semua hama pada foto, jumlah ekornya masuk rincian, dan status
/// rekomendasi ikut ditampilkan supaya petani tahu foto itu sudah ditindaklanjuti
/// atau belum (BUG-22).
V2PindaiItem v2PindaiItemFromScan(ScanEntry entry, String meja) {
  final detections = entry.scan.detections;
  int? keyakinan;
  for (final d in detections) {
    final persen = d.confidencePercent;
    if (persen != null && (keyakinan == null || persen > keyakinan)) {
      keyakinan = persen;
    }
  }
  return V2PindaiItem(
    id: entry.scan.id,
    hama: detections.isEmpty
        ? 'Tidak ada hama'
        : detections.map((d) => d.pest.label).join(', '),
    meja: meja,
    tanggal: entry.scan.detectedAt,
    keyakinan: keyakinan,
    status: switch (entry.status) {
      RecommendationStatus.menunggu => V2PindaiStatus.menunggu,
      RecommendationStatus.diterima => V2PindaiStatus.diterima,
      RecommendationStatus.ditolak => V2PindaiStatus.ditolak,
      null => null,
    },
    rincian: [
      for (final d in detections)
        '${d.pest.label} · ${d.count} ekor'
            '${d.confidencePercent == null ? '' : ' · ${d.confidencePercent}%'}',
    ],
  );
}

/// Nama meja untuk satu pindaian; pindaian pada meja yang sudah diarsipkan
/// tetap diberi label agar barisnya tidak kosong.
String _mejaLabel(List<TableRecord> tables, String tableId) {
  for (final table in tables) {
    if (table.id == tableId) return table.displayName;
  }
  return 'Meja $tableId';
}

/// Isi tab "Rawat" dari laporan kerusakan dan pindaian hama nyata.
///
/// Laporan diambil per meja lewat `damageProvider`; daftar meja berasal dari
/// provider meja yang sama dengan tab Tanam. Tombol "Foto tanaman" membuka
/// halaman deteksi hama di perangkat (`PestScanPage`), yang juga mengunggah
/// foto dan menyimpan saran rotasi obat. Setelah halaman itu ditutup, daftar
/// pindaian dan riwayat rotasi dimuat ulang supaya hasil simpan/terima/tolak
/// langsung terlihat (BUG-22).
class V2RawatConnectedTab extends ConsumerWidget {
  const V2RawatConnectedTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tables = ref.watch(connectedTableProvider);
    final scans = ref.watch(pestScansProvider);
    final items = <V2RawatItem>[];
    var loading = tables.loading || (scans.isLoading && !scans.hasValue);
    String? error = tables.error;
    for (final table in tables.records.where((row) => !row.isInactive)) {
      final damage = ref.watch(damageProvider(table.id));
      loading = loading || damage.loading;
      error ??= damage.error;
      for (final report in damage.reports.values.expand((rows) => rows)) {
        items.add(v2RawatItemFromDamage(report, table));
      }
    }
    error ??= scans.error == null ? null : pestErrorMessage(scans.error!);
    items.sort((a, b) => b.tanggal.compareTo(a.tanggal));
    final pindaian = [
      for (final entry in scans.value ?? const <ScanEntry>[])
        v2PindaiItemFromScan(entry, _mejaLabel(tables.records, entry.scan.tableId)),
    ];
    final kosong = items.isEmpty && pindaian.isEmpty;
    final state = switch ((loading, error, kosong)) {
      (true, _, true) => V2RawatState.loading,
      (_, _?, true) => V2RawatState.error,
      _ => V2RawatState.ready,
    };
    return V2RawatTabView(
      riwayat: items,
      pindaian: pindaian,
      showPindaian: error == null,
      state: state,
      onRetry: () => _refresh(ref, tables.records),
      onOpenCuaca: () =>
          Navigator.of(context).push(V2CuacaConnectedPage.route()),
      onOpenRotasi: () => _openRotasi(context, ref),
      onTapPindai: (item) => Navigator.of(context).push<void>(
        V2PindaiDetailPage.route(
          item,
          onOpenRotasi: () => _openRotasi(context, ref),
        ),
      ),
      onFotoTanaman: () => _openScan(context, ref),
      onTapItem: (item) => Navigator.of(context).push<void>(
        V2RawatDetailPage.route(item, showFoto: false),
      ),
    );
  }

  /// Buka alur pindai, lalu muat ulang daftar. Simpan, terima, dan tolak
  /// rekomendasi terjadi di dalam alur itu, jadi tidak ada sinyal lain yang
  /// bisa dipakai untuk menyegarkan tab ini.
  Future<void> _openScan(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push(PestScanPage.route());
    ref.invalidate(pestScansProvider);
    ref.invalidate(pestHistoryProvider);
  }

  /// Riwayat rotasi juga bisa menerima/menolak rekomendasi.
  Future<void> _openRotasi(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push(RotationHistoryPage.route());
    ref.invalidate(pestScansProvider);
  }

  Future<void> _refresh(WidgetRef ref, List<TableRecord> tables) async {
    for (final table in tables.where((row) => !row.isInactive)) {
      await ref.read(damageProvider(table.id).notifier).refresh();
    }
    await ref.read(connectedTableProvider.notifier).refresh();
    ref.invalidate(pestScansProvider);
  }
}