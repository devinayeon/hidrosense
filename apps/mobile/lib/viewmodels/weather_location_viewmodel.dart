import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/weather_location_repository.dart';
import '../data/services/device_locator.dart';
import '../models/weather_location.dart';
import 'session_viewmodel.dart';
import 'v2_sync_status.dart';

final deviceLocatorProvider = Provider<DeviceLocator>(
  (ref) => const GeolocatorDeviceLocator(),
);

final weatherLocationRepositoryProvider = Provider<WeatherLocationRepository>((
  ref,
) {
  final store = ref.watch(localKvStoreProvider);
  return WeatherLocationRepository(ref.watch(apiClientProvider), () => store);
});

/// Lokasi cuaca yang sedang dipakai seluruh aplikasi (halaman Cuaca, kartu di
/// Beranda, dan saran harian).
///
/// Dimulai dari lokasi mitra; [restore] memasang pilihan tersimpan sebelum
/// layar pertama digambar (lihat `main.dart`), jadi cuaca tidak sempat dimuat
/// untuk lokasi yang salah. Berganti lokasi membuat prakiraan dimuat ulang
/// karena `weatherViewModelProvider` mengamati state ini.
class WeatherLocationNotifier extends StateNotifier<WeatherLocation> {
  WeatherLocationNotifier(this._repository) : super(WeatherLocation.partner);

  final WeatherLocationRepository _repository;

  Future<void> restore() async {
    final saved = await _repository.current();
    if (mounted && saved != state) state = saved;
  }

  /// Memakai [location] dan menyimpannya di HP. State berubah lebih dulu
  /// supaya layar langsung memuat; kegagalan menyimpan hanya berarti pilihan
  /// tidak bertahan sampai aplikasi dibuka lagi.
  Future<void> select(WeatherLocation location) async {
    if (location == state) return;
    state = location;
    try {
      await _repository.save(location);
    } catch (_) {}
  }

  /// Desa tempat pengguna berada sekarang, lewat GPS lalu backend. Tidak
  /// langsung dipakai: pemanggil menampilkan hasilnya dulu (mis. bila
  /// [WeatherLocation.approximate]) lalu memanggil [select].
  Future<WeatherLocation> locateDevice(DeviceLocator locator) async {
    final position = await locator.currentPosition();
    return _repository.locate(position.lat, position.lon);
  }

  Future<List<WeatherRegion>> regions(
    WeatherRegionLevel level, {
    String? parent,
  }) => _repository.regions(level, parent: parent);
}

final weatherLocationProvider =
    StateNotifierProvider<WeatherLocationNotifier, WeatherLocation>(
      (ref) =>
          WeatherLocationNotifier(ref.watch(weatherLocationRepositoryProvider)),
    );
