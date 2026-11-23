import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/bmkg_weather_service.dart';
import '../core/weather_notice.dart';
import '../data/services/weather_notification_service.dart';
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
  WeatherViewModel({WeatherLoader? loader, bool autoLoad = true, this.onLoaded})
    : super(const WeatherState()) {
    _loader = loader;
    if (autoLoad) fetchWeatherData();
  }

  late final WeatherLoader? _loader;

  /// Dipanggil setiap kali cuaca berhasil dimuat, mis. untuk notifikasi saran harian.
  final void Function(WeatherData data)? onLoaded;
  int _requestGeneration = 0;

  Future<void> fetchWeatherData() async {
    final generation = ++_requestGeneration;
    state = state.copyWith(isLoading: true, clearError: true);

    final service = _loader == null ? BmkgWeatherService() : null;
    try {
      final data = await (_loader ?? service!.fetchWeather)();
      if (!mounted || generation != _requestGeneration) return;
      state = WeatherState(data: data, isLoading: false);
      onLoaded?.call(data);
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

/// Notifikasi saran cuaca (S6: tindakan cuaca hanya berupa notifikasi, tidak disimpan).
final weatherNoticeSinkProvider = Provider<WeatherNoticeSink>((ref) => LocalWeatherNotifier());

/// Kirim saran hari ini sebagai notifikasi. Hanya tindakan yang dipicu cuaca yang dikirim.
/// Dipakai saat aplikasi memuat cuaca dan oleh tugas latar (`weather_background.dart`).
Future<void> notifyTodayAdvice(WeatherData data, WeatherNoticeSink sink, DateTime now) async {
  if (data.prakiraanHarian.isEmpty) return;
  final notice = buildWeatherNotice(data.prakiraanHarian.first, now);
  if (notice != null) await sink.deliver(notice);
}

final weatherViewModelProvider =
    StateNotifierProvider.autoDispose<WeatherViewModel, WeatherState>((ref) {
      final service = ref.watch(bmkgWeatherServiceProvider);
      final sink = ref.watch(weatherNoticeSinkProvider);
      return WeatherViewModel(
        loader: service.fetchWeather,
        onLoaded: (data) => unawaited(notifyTodayAdvice(data, sink, DateTime.now())),
      );
    });
