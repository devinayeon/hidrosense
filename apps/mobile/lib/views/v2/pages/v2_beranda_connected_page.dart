import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/accounts/data/v2_employee_store.dart';
import '../../../viewmodels/v2_beranda_viewmodel.dart';
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
      weatherTitle: data.weatherTitle ?? 'Berawan, 29°C',
      weatherSubtitle: data.weatherSubtitle ?? 'Hujan 14.00',
      employeeStore: ref.watch(v2EmployeeStoreProvider),
      onLogOut: onLogOut,
    );
  }
}
