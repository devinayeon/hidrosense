import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hidrosense_mobile/data/services/weather_background.dart';
import 'package:hidrosense_mobile/viewmodels/session_viewmodel.dart';
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
  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AppGate(),
    );
  }
}
