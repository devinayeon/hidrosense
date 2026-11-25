import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hidrosense_mobile/data/services/weather_background.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
import 'package:hidrosense_mobile/viewmodels/weather_location_viewmodel.dart';
import 'package:hidrosense_mobile/views/pages/app_gate.dart';
import 'package:hidrosense_mobile/views/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Saran cuaca harian sebagai notifikasi walau aplikasi tidak dibuka (Android).
  unawaited(scheduleDailyWeatherAdvice());
  final container = ProviderContainer();
  // Sesi tersimpan dipulihkan sebelum layar pertama digambar supaya pengguna
  // yang sudah pernah masuk langsung tiba di beranda, tanpa melewati halaman
  // login. Yang ditunggu hanya pembacaan lokal; verifikasi token ke layanan
  // berjalan di latar belakang.
  try {
    await container.read(sessionProvider.notifier).restore();
  } catch (_) {
    // Tidak ada sesi tersimpan yang bisa dipakai; lanjut ke alur masuk.
  }
  try {
    // Lokasi cuaca pilihan dipasang sebelum layar pertama supaya prakiraan
    // tidak sempat dimuat untuk lokasi bawaan.
    await container.read(weatherLocationProvider.notifier).restore();
  } catch (_) {
    // Pakai lokasi bawaan.
  }
  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // Skala huruf sistem dihormati sampai 1,5x. Di atas itu tata letak
      // yang dirancang untuk layar 360-412 dp tidak lagi muat, dan layar
      // yang meluap lebih merugikan pengguna daripada huruf yang dibatasi.
      builder: (context, child) =>
          MediaQuery.withClampedTextScaling(maxScaleFactor: 1.5, child: child!),
      home: const AppGate(),
    );
  }
}
