import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/weather_location.dart';
import '../../../viewmodels/weather_location_viewmodel.dart';
import '../../../viewmodels/weather_viewmodel.dart';
import '../components/v2_cuaca_lokasi_sheet.dart';
import '../pages/v2_cuaca_page.dart';
import '../widgets/v2_bottom_sheet.dart';

/// Halaman Cuaca yang membaca prakiraan BMKG nyata untuk lokasi pilihan
/// pengguna.
///
/// Lokasi bisa dipilih dari seluruh Indonesia: lewat GPS ("Gunakan lokasi
/// saya") atau mencari dari provinsi sampai desa/kelurahan. Pilihan disimpan
/// di HP, dipakai juga oleh kartu cuaca Beranda dan saran harian, dan
/// berganti lokasi langsung memuat ulang prakiraan. Saran pada tab ketiga
/// memakai aturan cuaca lokal (`weather_rules`) dan logika fuzzy atas
/// prakiraan lokasi itu.
class V2CuacaConnectedPage extends ConsumerWidget {
  const V2CuacaConnectedPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
    settings: const RouteSettings(name: 'v2-cuaca'),
    builder: (_) => const V2CuacaConnectedPage(),
  );

  Future<void> _pilihLokasi(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(weatherLocationProvider.notifier);
    final picked = await showV2BottomSheet<WeatherLocation>(
      context,
      child: V2CuacaLokasiSheet(
        current: ref.read(weatherLocationProvider),
        loadRegions: (level, parent) => notifier.regions(level, parent: parent),
        locateDevice: () =>
            notifier.locateDevice(ref.read(deviceLocatorProvider)),
      ),
    );
    if (picked == null) return;
    await notifier.select(picked);
    if (picked.approximate && context.mounted) {
      // Desa persis pengguna tidak ada di daftar; yang dipakai desa terdekat
      // di kecamatan yang sama. Dikatakan terang-terangan, bukan diam-diam.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Memakai ${picked.village}, desa terdekat di Kecamatan '
            '${picked.district}.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(weatherViewModelProvider);
    final location = ref.watch(weatherLocationProvider);
    final data = state.data;
    return V2CuacaPage(
      data: data,
      memuat: state.isLoading && data == null,
      bmkgGagal: state.errorMessage != null && data == null,
      lokasiLabel: location.label,
      onRetry: () =>
          ref.read(weatherViewModelProvider.notifier).fetchWeatherData(),
      onPilihLokasi: (pageContext) => _pilihLokasi(pageContext, ref),
    );
  }
}
