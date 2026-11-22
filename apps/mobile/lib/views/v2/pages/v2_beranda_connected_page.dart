import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/sync_queue_item.dart';
import '../../../features/accounts/data/v2_employee_store.dart';
import '../../../features/accounts/presentation/viewmodels/profile_viewmodel.dart';
import '../../../viewmodels/session_viewmodel.dart';
import '../../../viewmodels/v2_beranda_viewmodel.dart';
import '../../../viewmodels/v2_penjualan_store.dart';
import '../../../viewmodels/v2_sync_queue.dart';
import '../connected/v2_cuaca_connected.dart';
import '../connected/v2_inventaris_connected.dart';
import '../connected/v2_notifications_connected.dart';
import '../connected/v2_rawat_connected.dart';
import '../connected/v2_tanam_connected.dart';
import 'v2_beranda_page.dart';

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
          ref
              .read(sessionProvider)
              .user
              ?.permissions
              .contains('profil:read') ??
          false;
      if (canReadProfile) {
        ref.read(profileViewModelProvider.notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(v2BerandaDataProvider);
    final profile = ref.watch(
      profileViewModelProvider.select((state) => state.profile),
    );
    final syncItems = ref.watch(v2SyncQueueProvider);
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
      heroTitle: data.heroTitle,
      heroSubtitle: data.heroSubtitle,
      heroValue: data.heroValue,
      heroTotal: data.heroTotal,
      weatherTitle: data.weatherTitle ?? 'Berawan, 29°C',
      weatherSubtitle: data.weatherSubtitle ?? 'Hujan 14.00',
      employeeStore: ref.watch(v2EmployeeStoreProvider),
      penjualanStore: ref.watch(v2PenjualanStoreProvider),
      syncQueue: ref.watch(v2SyncQueueProvider.notifier),
      syncReplayer: ref.watch(v2SyncReplayerProvider),
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
      onOpenNotifications: () =>
          Navigator.of(context).push(V2NotificationsConnectedPage.route()),
      onOpenWeather: () =>
          Navigator.of(context).push(V2CuacaConnectedPage.route()),
      syncLabel: syncItems.isEmpty
          ? 'Semua data tersinkron'
          : '${syncItems.length} data menunggu',
      syncBadge: syncItems.isEmpty
          ? null
          : gagal > 0
          ? 'Gagal $gagal'
          : 'Antrean $menunggu',
      onLogOut: widget.onLogOut,
    );
  }
}
