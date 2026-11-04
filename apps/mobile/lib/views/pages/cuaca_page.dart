import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/weather_viewmodel.dart';
import '../components/cuaca_body.dart';
import '../components/header.dart';

class CuacaPage extends ConsumerWidget {
  const CuacaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      weatherViewModelProvider.select((state) => state.isLoading),
    );

    return Scaffold(
      appBar: Header(
        titleText: 'Cuaca & Iklim',
        showBackButton: true,
        actions: [
          IconButton(
            key: const ValueKey('weather-refresh'),
            tooltip: 'Perbarui prakiraan cuaca',
            onPressed: isLoading
                ? null
                : () => ref
                      .read(weatherViewModelProvider.notifier)
                      .fetchWeatherData(),
            icon: const Icon(Icons.refresh_rounded, size: 22),
          ),
        ],
      ),
      body: const CuacaBody(),
    );
  }
}
