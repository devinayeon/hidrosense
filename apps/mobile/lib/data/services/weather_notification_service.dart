import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/weather_notice.dart';
import 'notification_permission_service.dart';

/// Tujuan pengiriman notifikasi saran cuaca. Diganti di tes.
abstract interface class WeatherNoticeSink {
  Future<void> deliver(WeatherNotice notice);
}

/// Notifikasi lokal Android untuk saran cuaca BMKG.
///
/// Hanya dikirim bila izin notifikasi sudah diberikan (lewat alur izin yang ada). Notifikasi
/// hari yang sama memakai id yang sama dan `onlyAlertOnce`, jadi memuat ulang cuaca memperbarui
/// isinya tanpa bunyi ulang. Kegagalan plugin tidak boleh mengganggu halaman cuaca.
class LocalWeatherNotifier implements WeatherNoticeSink {
  LocalWeatherNotifier({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const _channelId = 'cuaca_bmkg';

  @override
  Future<void> deliver(WeatherNotice notice) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      if (!await NotificationPermissionService.isGranted()) return;
      if (!_ready) {
        await _plugin.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          ),
        );
        _ready = true;
      }
      await _plugin.show(
        id: notice.id,
        title: notice.title,
        body: notice.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Saran cuaca BMKG',
            channelDescription: 'Saran perawatan dari prakiraan cuaca. Boleh diabaikan.',
            onlyAlertOnce: true,
          ),
        ),
      );
    } on Exception catch (error) {
      debugPrint('Notifikasi cuaca gagal: $error');
    }
  }
}
