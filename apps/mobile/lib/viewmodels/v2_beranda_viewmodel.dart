import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/inventory_record.dart';
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

  /// Jumlah barang dengan stok di bawah minimum (termasuk yang habis), lintas
  /// jenis — sama dengan isi daftar yang dibuka kartu di Beranda.
  final String lowStockCount;

  /// Total lubang terisi dari semua meja aktif.
  final String filledHoles;

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
  final lowStock = berandaLowStockCount(inventory.activeRecords);
  final filledHoles = tables.records
      .where((table) => table.isActive)
      .fold<int>(0, (sum, table) => sum + table.activePlants);

  return V2BerandaData(
    loading: nursery.loading || inventory.isInitialLoading,
    weatherUnavailable: canReadWeather && weather.errorMessage != null,
    readySeedlingCount: ready.length,
    readySeedlingSubtitle: _readySubtitle(ready),
    lowStockCount: '$lowStock',
    filledHoles: '$filledHoles',
    weatherTitle: _weatherTitle(weather.data),
    weatherSubtitle: _weatherSubtitle(weather.data),
  );
});

String _readySubtitle(List<SowingRecord> ready) {
  if (ready.isEmpty) return 'Belum ada semaian siap pindah';
  final hss = ready.first.hssText;
  return ready.length == 1
      ? '1 semaian, $hss'
      : '${ready.length} semaian, $hss';
}

String? _weatherTitle(WeatherData? data) {
  if (data == null) return null;
  return '${data.estimasiHujan}, ${data.suhu}°C';
}

String? _weatherSubtitle(WeatherData? data) {
  if (data == null) return null;
  return 'Curah hujan ${data.curahHujan}';
}

/// Barang yang dihitung kartu "Stok menipis" di Beranda.
///
/// Cakupannya sama dengan daftar yang dibuka kartu itu (saringan "Menipis" =
/// bukan aman): semua jenis barang yang **di bawah** stok minimum atau sudah
/// habis. Dengan begitu angka kartu selalu sama dengan jumlah baris daftar
/// (BUG-06); barang yang tepat di angka minimum tidak dihitung (BUG-03).
bool isBerandaLowStock(InventoryRecord item) =>
    item.isLow || item.isOutOfStock;

/// Jumlah barang "Stok menipis" untuk kartu Beranda.
int berandaLowStockCount(Iterable<InventoryRecord> records) =>
    records.where(isBerandaLowStock).length;
