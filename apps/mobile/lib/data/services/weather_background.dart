import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../../models/weather_model.dart';
import '../repositories/weather_location_repository.dart';
import 'bmkg_weather_service.dart';
import 'local_kv_store.dart';
import 'weather_notification_service.dart';

/// Nama tugas latar saran cuaca harian (Android WorkManager).
const String kWeatherTaskName = 'hidrosense.cuaca-harian';

/// Satu putaran tugas latar: muat BMKG, kirim saran hari ini sebagai notifikasi.
///
/// Selalu mengembalikan true. Gagal jaringan tidak dicoba ulang dengan backoff: tugas periodik
/// akan berjalan lagi pada jadwal berikutnya, dan saran cuaca yang terlambat tidak berguna.
/// Tidak ada yang disimpan (S8): notifikasi hari yang sama menimpa yang sebelumnya.
Future<bool> runDailyWeatherTask({
  required Future<WeatherData> Function() load,
  required WeatherNoticeSink sink,
  required DateTime now,
}) async {
  try {
    await notifyTodayAdvice(await load(), sink, now);
  } on Exception catch (error) {
    debugPrint('Tugas cuaca latar gagal: $error');
  }
  return true;
}

/// Titik masuk isolate latar. Harus fungsi tingkat atas dan tidak boleh dibuang tree shaking.
@pragma('vm:entry-point')
void weatherCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != kWeatherTaskName) return true;
    WidgetsFlutterBinding.ensureInitialized();
    // Saran harian mengikuti lokasi yang dipilih pengguna, bukan lokasi mitra.
    final location = await WeatherLocationRepository.savedOrDefault(
      LocalKvStore.open,
    );
    final service = BmkgWeatherService(adm4: location.adm4);
    try {
      return await runDailyWeatherTask(
        load: service.fetchWeather,
        sink: LocalWeatherNotifier(),
        now: DateTime.now(),
      );
    } finally {
      service.close();
    }
  });
}

/// Jadwalkan tugas setiap 12 jam saat ada jaringan. `keep` menjaga jadwal yang sudah ada,
/// jadi membuka aplikasi berkali-kali tidak menumpuk tugas. Hanya Android.
Future<void> scheduleDailyWeatherAdvice() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await Workmanager().initialize(weatherCallbackDispatcher);
    await Workmanager().registerPeriodicTask(
      kWeatherTaskName,
      kWeatherTaskName,
      frequency: const Duration(hours: 12),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  } on Exception catch (error) {
    debugPrint('Penjadwalan cuaca latar gagal: $error');
  }
}
