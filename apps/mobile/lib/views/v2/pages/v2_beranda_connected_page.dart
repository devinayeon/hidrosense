import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/sync_queue_item.dart';
import '../../../features/accounts/data/v2_employee_store.dart';
import '../../../viewmodels/v2_penjualan_store.dart';
import '../../../viewmodels/v2_sync_queue.dart';
import '../../../viewmodels/v2_sync_status.dart';
import '../../../viewmodels/v2_beranda_viewmodel.dart';
import '../components/v2_sinkron_data.dart';
import 'v2_sinkron_page.dart';
import '../connected/v2_cuaca_connected.dart';
import '../connected/v2_inventaris_connected.dart';
import '../connected/v2_rawat_connected.dart';
import '../connected/v2_tanam_connected.dart';
import 'v2_beranda_page.dart';

/// Beranda v2 yang diisi data nyata (frame 2.1–2.6).
///
/// Angka dan teks diambil dari provider yang sudah ada: semaian siap pindah
/// (penyemaian), stok menipis (inventaris), lubang terisi (meja), dan cuaca
/// BMKG. Halaman ini yang dipakai `AppGate`; versi fixture di
/// `v2_beranda_page.dart` tetap dipakai galeri untuk mencocokkan frame.
class V2BerandaConnectedPage extends ConsumerWidget {
  const V2BerandaConnectedPage({
    super.key,
    this.userName = 'Budi',
    this.fullName = 'Budi Santoso',
    this.username = 'sari.dewi',
    this.role = V2BerandaRole.petani,
    this.onLogOut,
  });

  final String userName;
  final String fullName;
  final String username;
  final V2BerandaRole role;
  final Future<void> Function()? onLogOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(v2BerandaDataProvider);
    final syncItems = ref.watch(v2SyncQueueProvider);
    final lastSync = ref.watch(v2SyncStatusProvider);
    final syncStatus = ref.read(v2SyncStatusProvider.notifier);
    final replayer = ref.watch(v2SyncReplayerProvider);
    final gagal = syncItems
        .where((item) => item.status == SyncQueueStatus.gagal)
        .length;
    final menunggu = syncItems.length - gagal;
    final state = switch (data) {
      V2BerandaData(loading: true) => V2BerandaState.loading,
      V2BerandaData(weatherUnavailable: true) =>
        V2BerandaState.weatherUnavailable,
      _ => V2BerandaState.ready,
    };

    return V2BerandaPage(
      userName: userName,
      fullName: fullName,
      username: username,
      role: role,
      state: state,
      siapPindahSubtitle: data.readySeedlingSubtitle,
      lowStock: data.lowStockCount,
      filledHoles: data.filledHoles,
      // Selama cuaca dimuat tidak ada angka karangan; teks contoh hanya milik galeri.
      weatherTitle: data.weatherTitle ?? 'Memuat cuaca...',
      weatherSubtitle: data.weatherSubtitle ?? 'Prakiraan BMKG',
      employeeStore: ref.watch(v2EmployeeStoreProvider),
      penjualanStore: ref.watch(v2PenjualanStoreProvider),
      syncQueue: ref.watch(v2SyncQueueProvider.notifier),
      syncReplayer: replayer,
      saleRepairer: switch (ref.watch(v2PenjualanStoreProvider)) {
        final V2PenjualanRepairer repairer => repairer,
        _ => null,
      },
      tanamTab: const V2TanamConnectedTab(),
      stokTabBuilder: (jenis, status) => V2InventarisConnectedTab(
        key: ValueKey('stok-${jenis?.name}-$status'),
        initialJenis: jenis,
        initialStatusIndex: status,
      ),
      rawatTab: const V2RawatConnectedTab(),
      onOpenWeather: () =>
          Navigator.of(context).push(V2CuacaConnectedPage.route()),
      syncLink: V2SyncLink(
        lastSyncedAt: lastSync,
        refresh: syncStatus.refresh,
        record: () => syncStatus.markSynced(trustLocal: true),
        syncNow: replayer == null
            ? null
            : (onProgress) => v2SyncRound(
                run: () => replayer.run(onProgress: onProgress),
                markSynced: syncStatus.markSynced,
              ),
      ),
      syncLabel: syncItems.isEmpty
          ? (lastSync == null
                ? 'Belum pernah sinkron'
                : 'Terakhir ${v2SinkronJam(lastSync)}')
          : '${syncItems.length} data menunggu',
      syncBadge: syncItems.isEmpty
          ? null
          : gagal > 0
          ? 'Gagal $gagal'
          : 'Antrean $menunggu',
      onLogOut: onLogOut,
    );
  }
}
