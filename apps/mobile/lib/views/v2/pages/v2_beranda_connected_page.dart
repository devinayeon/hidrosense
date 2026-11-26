import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/sync_queue_item.dart';
import '../../../features/accounts/data/v2_employee_store.dart';
import '../../../viewmodels/connected_inventory_viewmodel.dart';
import '../../../viewmodels/connected_nursery_viewmodel.dart';
import '../../../viewmodels/session_viewmodel.dart';
import '../../../features/accounts/presentation/viewmodels/profile_viewmodel.dart';
import '../../../viewmodels/v2_beranda_viewmodel.dart';
import '../../../viewmodels/v2_penjualan_store.dart';
import '../../../viewmodels/v2_notification_read.dart';
import '../../../viewmodels/v2_sync_queue.dart';
import '../../../viewmodels/v2_sync_status.dart';
import '../components/v2_sinkron_data.dart';
import 'v2_sinkron_page.dart';
import '../connected/v2_beranda_notifikasi.dart';
import '../connected/v2_cuaca_connected.dart';
import '../connected/v2_inventaris_connected.dart';
import '../connected/v2_rawat_connected.dart';
import '../connected/v2_tanam_connected.dart';
import 'v2_beranda_page.dart';
import 'v2_notifications_page.dart';
import 'v2_profile_detail_page.dart';

/// Beranda v2 yang diisi data nyata (frame 2.1–2.6).
///
/// Angka dan teks diambil dari provider yang sudah ada: semaian siap pindah
/// (penyemaian), stok menipis (inventaris), lubang terisi (meja), profil akun,
/// notifikasi, dan cuaca BMKG. Halaman ini yang dipakai `AppGate`; versi
/// fixture di `v2_beranda_page.dart` tetap dipakai galeri.
class V2BerandaConnectedPage extends ConsumerStatefulWidget {
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
  ConsumerState<V2BerandaConnectedPage> createState() =>
      _V2BerandaConnectedPageState();
}

class _V2BerandaConnectedPageState
    extends ConsumerState<V2BerandaConnectedPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (!mounted) return;
      final canReadProfile =
          ref.read(sessionProvider).user?.permissions.contains('profil:read') ??
          false;
      if (canReadProfile) {
        ref.read(profileViewModelProvider.notifier).load();
      }
    });
  }

  /// Membuka detail profil sendiri lalu menyegarkan kartu profil di beranda.
  /// Setelah username/password diubah, `clearLocalSession` melepas halaman ini
  /// sebelum push selesai, jadi pemeriksaan `mounted` penting.
  Future<void> _openProfile() async {
    var profile = ref.read(profileViewModelProvider).profile;
    if (profile == null) {
      // Sesi lama bisa belum memuat profil (mis. izin baru setelah layanan
      // diperbarui); coba muat sekali lagi sebelum menyerah.
      await ref.read(profileViewModelProvider.notifier).load();
      if (!mounted) return;
      profile = ref.read(profileViewModelProvider).profile;
      if (profile == null) {
        final message =
            ref.read(profileViewModelProvider).errorMessage ??
            'Profil belum termuat. Coba lagi.';
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
        return;
      }
    }
    final canDeactivate =
        ref
            .read(sessionProvider)
            .user
            ?.permissions
            .contains('profil:deactivate') ??
        false;
    await Navigator.of(context).push<void>(
      V2ProfileDetailPage.route(
        profile: profile,
        canDeactivate: canDeactivate,
      ),
    );
    if (!mounted) return;
    await ref.read(profileViewModelProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(v2BerandaDataProvider);
    final profile = ref.watch(
      profileViewModelProvider.select((state) => state.profile),
    );
    final syncItems = ref.watch(v2SyncQueueProvider);
    final lastSync = ref.watch(v2SyncStatusProvider);
    final syncStatus = ref.read(v2SyncStatusProvider.notifier);
    final replayer = ref.watch(v2SyncReplayerProvider);
    // Provider inventaris/penyemaian melempar saat belum ada sesi; jaga agar
    // transisi keluar akun tidak membangun notifikasi dari sesi kosong.
    // Provider penyemaian juga melempar bila peran tidak punya izin baca, jadi
    // tiap sumber hanya dibaca bila izinnya ada (sama seperti beranda).
    final user = ref.watch(sessionProvider.select((state) => state.user));
    final permissions = user?.permissions ?? const <String>[];
    final notifikasi = user == null
        ? const <V2NotificationGroup>[]
        : v2BerandaNotifikasi(
            nursery: permissions.contains('penyemaian:read')
                ? ref.watch(connectedNurseryProvider).records
                : const [],
            inventaris: permissions.contains('inventaris:read')
                ? ref.watch(connectedInventoryProvider).activeRecords
                : const [],
            sudahDibaca: ref.watch(v2NotificationReadProvider),
          );
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

    final phone = profile?.noTelepon?.trim();
    final address = profile?.alamat?.trim();

    return V2BerandaPage(
      userName: widget.userName,
      fullName: profile?.nama ?? widget.fullName,
      username: profile?.username ?? widget.username,
      phone: phone == null || phone.isEmpty ? '-' : phone,
      address: address == null || address.isEmpty ? '-' : address,
      role: widget.role,
      state: state,
      siapPindahSubtitle: data.readySeedlingSubtitle,
      lowStock: data.lowStockCount,
      filledHoles: data.filledHoles,
      // Selama cuaca dimuat tidak ada angka karangan; teks contoh hanya milik galeri.
      weatherTitle: data.weatherTitle ?? 'Memuat cuaca...',
      weatherSubtitle: data.weatherSubtitle ?? 'Prakiraan BMKG',
      heroTitle: data.heroTitle,
      heroSubtitle: data.heroSubtitle,
      heroValue: data.heroValue,
      heroTotal: data.heroTotal,
      employeeStore: ref.watch(v2EmployeeStoreProvider),
      penjualanStore: ref.watch(v2PenjualanStoreProvider),
      syncQueue: ref.watch(v2SyncQueueProvider.notifier),
      syncReplayer: replayer,
      saleRepairer: switch (ref.watch(v2PenjualanStoreProvider)) {
        final V2PenjualanRepairer repairer => repairer,
        _ => null,
      },
      tanamTabBuilder: (segmen, onOpenSemaian) => V2TanamConnectedTab(
        initialSegmen: segmen,
        onOpenSemaian: onOpenSemaian,
        key: ValueKey(segmen),
      ),
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
      notificationGroups: notifikasi,
      onNotificationRead: (id) =>
          ref.read(v2NotificationReadProvider.notifier).markRead(id),
      onNotificationMarkAllRead: (ids) =>
          ref.read(v2NotificationReadProvider.notifier).markAll(ids),
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
      onLogOut: widget.onLogOut,
      onOpenProfile: _openProfile,
    );
  }
}
