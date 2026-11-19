import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../viewmodels/weather_viewmodel.dart';
import '../components/v2_cuaca_data.dart';
import '../pages/v2_cuaca_page.dart';

/// Halaman Cuaca yang membaca prakiraan BMKG nyata.
///
/// BMKG hanya memberi satu lokasi mitra, jadi sheet lokasi berisi satu baris
/// berisi desa/kecamatan dari layanan. Saran pada tab ketiga memakai aturan
/// cuaca lokal (`weather_rules`) yang sudah dipakai aplikasi v1.
class V2CuacaConnectedPage extends ConsumerWidget {
  const V2CuacaConnectedPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
    settings: const RouteSettings(name: 'v2-cuaca'),
    builder: (_) => const V2CuacaConnectedPage(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(weatherViewModelProvider);
    final data = state.data;
    final lokasi = data == null
        ? null
        : <V2CuacaLokasi>[
            V2CuacaLokasi(nama: data.lokasi, wilayah: data.kota),
          ];
    return V2CuacaPage(
      data: data,
      memuat: state.isLoading && data == null,
      bmkgGagal: state.errorMessage != null && data == null,
      lokasiList: lokasi,
      lokasiLabel: data == null ? null : '${data.lokasi}, ${data.kota}',
      onRetry: () =>
          ref.read(weatherViewModelProvider.notifier).fetchWeatherData(),
    );
  }
}