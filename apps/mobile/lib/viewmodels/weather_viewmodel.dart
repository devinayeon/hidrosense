import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/bmkg_weather_service.dart';
import '../models/weather_model.dart';

class WeatherState {
  final WeatherData? data;
  final bool isLoading;
  final String? errorMessage;

  const WeatherState({this.data, this.isLoading = false, this.errorMessage});

  WeatherState copyWith({
    WeatherData? data,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return WeatherState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

typedef WeatherLoader = Future<WeatherData> Function();

final bmkgWeatherServiceProvider = Provider.autoDispose<BmkgWeatherService>((
  ref,
) {
  final service = BmkgWeatherService();
  ref.onDispose(service.close);
  return service;
});

class WeatherViewModel extends StateNotifier<WeatherState> {
  WeatherViewModel({WeatherLoader? loader, bool autoLoad = true})
    : super(const WeatherState()) {
    _loader = loader;
    if (autoLoad) fetchWeatherData();
  }

  late final WeatherLoader? _loader;
  int _requestGeneration = 0;

  Future<void> fetchWeatherData() async {
    final generation = ++_requestGeneration;
    state = state.copyWith(isLoading: true, clearError: true);

    final service = _loader == null ? BmkgWeatherService() : null;
    try {
      final data = await (_loader ?? service!.fetchWeather)();
      if (!mounted || generation != _requestGeneration) return;
      state = WeatherState(data: data, isLoading: false);
    } catch (_) {
      if (!mounted || generation != _requestGeneration) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            'Gagal memuat data cuaca BMKG. Periksa koneksi internet, lalu coba lagi.',
      );
    } finally {
      service?.close();
    }
  }

  @override
  void dispose() {
    _requestGeneration++;
    super.dispose();
  }
}

final weatherViewModelProvider =
    StateNotifierProvider.autoDispose<WeatherViewModel, WeatherState>((ref) {
      final service = ref.watch(bmkgWeatherServiceProvider);
      return WeatherViewModel(loader: service.fetchWeather);
    });
