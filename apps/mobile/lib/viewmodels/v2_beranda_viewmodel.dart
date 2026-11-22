import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/nursery_record.dart';
import '../models/weather_model.dart';
import 'connected_inventory_viewmodel.dart';
import 'connected_nursery_viewmodel.dart';
import 'connected_table_viewmodel.dart';
import 'session_viewmodel.dart';
import 'weather_viewmodel.dart';

/// Data nyata untuk beranda v2 (frame 2.1–2.6).
///
/// Hanya berisi angka dan teks yang mengisi susunan desain; pemetaan ke
/// keadaan frame (memuat / BMKG gagal) dilakukan di halaman penghubung supaya
/// provider ini tetap murni dan mudah diuji.
class V2BerandaData {
  const V2BerandaData({
    this.loading = false,
    this.weatherUnavailable = false,
    this.readySeedlingCount = 0,
    this.readySeedlingSubtitle = 'Belum ada semaian siap pindah',
    this.lowStockCount = '0',
    this.filledHoles = '0',
    this.heroTitle = 'Belum ada siklus',
    this.heroSubtitle = 'Mulai dari semai benih',
    this.heroValue = 0,
    this.heroTotal = 60,
    this.weatherTitle,
    this.weatherSubtitle,
  });

  /// Salah satu sumber masih memuat dan belum punya data sama sekali.
  final bool loading;

  /// Layanan BMKG mengembalikan galat (frame 2.6).
  final bool weatherUnavailable;

  /// Jumlah semaian aktif yang siap pindah.
  final int readySeedlingCount;

  /// Subjudul baris "Siap pindah", mis. `2 semaian, HSS 15`.
  final String readySeedlingSubtitle;

  /// Jumlah barang dengan stok di bawah minimum.
  final String lowStockCount;

  /// Total lubang terisi dari semua meja aktif.
  final String filledHoles;

  /// Judul kartu hero siklus berjalan (nama meja aktif / semaian aktif).
  final String heroTitle;

  /// Subjudul kartu hero siklus berjalan.
  final String heroSubtitle;

  /// Nilai HSS pada cincin siklus.
  final int heroValue;

  /// Total hari siklus (bawaan 60 HSS).
  final int heroTotal;

  /// Judul kartu cuaca, mis. `Berawan, 29°C`. Null saat cuaca tak tersedia.
  final String? weatherTitle;

  /// Subjudul kartu cuaca, mis. `Curah hujan 0 mm`.
  final String? weatherSubtitle;
}

final v2BerandaDataProvider = Provider.autoDispose<V2BerandaData>((ref) {
  final user = ref.watch(sessionProvider.select((state) => state.user));
  if (user == null) return const V2BerandaData();

  final canReadNursery = user.permissions.contains('penyemaian:read');
  final nursery = canReadNursery
      ? ref.watch(connectedNurseryProvider)
      : const ConnectedNurseryState();

  final canReadInventory = user.permissions.contains('inventaris:read');
  final inventory = canReadInventory
      ? ref.watch(connectedInventoryProvider)
      : const ConnectedInventoryState();

  final canReadTables = user.permissions.contains('budidaya:read');
  final tables = canReadTables
      ? ref.watch(connectedTableProvider)
      : const TableState();

  final canReadWeather = user.permissions.contains('cuaca:read');
  final weather = canReadWeather
      ? ref.watch(weatherViewModelProvider)
      : const WeatherState();

  final ready = nursery.records.where((item) => item.canTransfer).toList();
  final lowStock = inventory.activeRecords.where((item) => item.isLow).length;
  final activeTables = tables.records
      .where((table) => table.isActive)
      .toList();
  final filledHoles = activeTables.fold<int>(
    0,
    (sum, table) => sum + table.activePlants,
  );
  final populatedTable = activeTables
      .where((table) => table.activePlants > 0)
      .firstOrNull;
  final activeNursery = nursery.records
      .where((item) => item.remainingSeedCount > 0)
      .firstOrNull;

  final String heroTitle;
  final String heroSubtitle;
  final int heroValue;
  if (populatedTable != null) {
    final hss = (activeNursery?.ageDays ?? 15).clamp(0, 60);
    final remaining = (60 - hss).clamp(0, 60);
    heroTitle = populatedTable.displayName;
    heroSubtitle = remaining == 0 ? 'Siap panen' : '$remaining hari lagi';
    heroValue = hss;
  } else if (activeNursery != null) {
    final hss = (activeNursery.ageDays ?? 0).clamp(0, 60);
    final remaining = (60 - hss).clamp(0, 60);
    heroTitle = 'Semaian aktif';
    heroSubtitle = '$remaining hari lagi';
    heroValue = hss;
  } else {
    heroTitle = 'Belum ada siklus';
    heroSubtitle = 'Mulai dari semai benih';
    heroValue = 0;
  }

  return V2BerandaData(
    loading: nursery.loading || inventory.isInitialLoading,
    weatherUnavailable: canReadWeather && weather.errorMessage != null,
    readySeedlingCount: ready.length,
    readySeedlingSubtitle: _readySubtitle(ready),
    lowStockCount: '$lowStock',
    filledHoles: '$filledHoles',
    heroTitle: heroTitle,
    heroSubtitle: heroSubtitle,
    heroValue: heroValue,
    weatherTitle: _weatherTitle(weather.data),
    weatherSubtitle: _weatherSubtitle(weather.data),
  );
});

String _readySubtitle(List<SowingRecord> ready) {
  if (ready.isEmpty) return 'Belum ada semaian siap pindah';
  final hss = ready.first.hssText;
  return ready.length == 1 ? '1 semaian, $hss' : '${ready.length} semaian, $hss';
}

String? _weatherTitle(WeatherData? data) {
  if (data == null) return null;
  return '${data.estimasiHujan}, ${data.suhu}°C';
}

String? _weatherSubtitle(WeatherData? data) {
  if (data == null) return null;
  return 'Curah hujan ${data.curahHujan}';
}
