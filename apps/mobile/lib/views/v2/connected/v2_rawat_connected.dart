import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/damage_record.dart';
import '../../../data/models/table_record.dart';
import '../../../viewmodels/connected_table_viewmodel.dart';
import '../../../features/pest/presentation/pages/pest_scan_page.dart';
import '../../../viewmodels/damage_viewmodel.dart';
import '../components/v2_rawat_data.dart';
import '../pages/v2_rawat_detail_page.dart';
import '../pages/v2_rawat_list_page.dart';
import 'v2_cuaca_connected.dart';

/// Satu laporan kerusakan backend → baris riwayat tab Rawat.
///
/// Backend hanya menyimpan jenis kerusakan dan jumlah tanaman; tidak ada
/// perawatan, obat, atau foto. Karena itu `meta`/`extra` diisi apa adanya dan
/// kartu detail memakai [V2RawatDetailPage] tanpa kartu foto AI.
V2RawatItem v2RawatItemFromDamage(DamageRecord damage, TableRecord table) {
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

/// Isi tab "Rawat" dari laporan kerusakan nyata semua meja.
///
/// Laporan diambil per meja lewat `damageProvider`; daftar meja berasal dari
/// provider meja yang sama dengan tab Tanam. Alur foto/AI belum punya endpoint
/// sehingga tombol "Foto tanaman" hanya menjelaskan hal itu.
class V2RawatConnectedTab extends ConsumerWidget {
  const V2RawatConnectedTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tables = ref.watch(connectedTableProvider);
    final items = <V2RawatItem>[];
    var loading = tables.loading;
    String? error = tables.error;
    for (final table in tables.records.where((row) => !row.isInactive)) {
      final damage = ref.watch(damageProvider(table.id));
      loading = loading || damage.loading;
      error ??= damage.error;
      for (final report in damage.reports.values.expand((rows) => rows)) {
        items.add(v2RawatItemFromDamage(report, table));
      }
    }
    items.sort((a, b) => b.tanggal.compareTo(a.tanggal));
    final state = switch ((loading, error, items.isEmpty)) {
      (true, _, true) => V2RawatState.loading,
      (_, _?, true) => V2RawatState.error,
      _ => V2RawatState.ready,
    };
    return V2RawatTabView(
      riwayat: items,
      state: state,
      onRetry: () => _refresh(ref, tables.records),
      onOpenCuaca: () =>
          Navigator.of(context).push(V2CuacaConnectedPage.route()),
      onFotoTanaman: () => Navigator.of(context).push(PestScanPage.route()),
      onTapItem: (item) => Navigator.of(
        context,
      ).push<void>(V2RawatDetailPage.route(item, showFoto: false)),
    );
  }

  Future<void> _refresh(WidgetRef ref, List<TableRecord> tables) async {
    for (final table in tables.where((row) => !row.isInactive)) {
      await ref.read(damageProvider(table.id).notifier).refresh();
    }
    await ref.read(connectedTableProvider.notifier).refresh();
  }
}
