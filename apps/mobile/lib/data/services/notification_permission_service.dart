import 'package:app_settings/app_settings.dart';
import 'package:permission_handler/permission_handler.dart';

/// Izin notifikasi sistem untuk alur v2.
///
/// Dipakai dua tempat: frame `1.10 Izin notifikasi` (minta izin sungguhan saat
/// tombol Aktifkan ditekan) dan frame `11.3 Notifikasi mati` (tombol Buka
/// pengaturan). Semua panggilan dibungkus supaya halaman tetap jalan di
/// lingkungan yang tidak punya plugin native (mis. widget test).
abstract final class NotificationPermissionService {
  /// Meminta izin notifikasi. `true` kalau pengguna mengizinkan.
  static Future<bool> request() async {
    if (!await _isSupported()) return false;
    try {
      final status = await Permission.notification.request();
      return status.isGranted;
    } on Exception {
      return false;
    }
  }

  /// Status izin saat ini tanpa memunculkan dialog.
  static Future<bool> isGranted() async {
    if (!await _isSupported()) return false;
    try {
      final status = await Permission.notification.status;
      return status.isGranted;
    } on Exception {
      return false;
    }
  }

  /// Buka pengaturan notifikasi aplikasi di sistem.
  static Future<void> openSettings() async {
    if (!await _isSupported()) return;
    try {
      await AppSettings.openAppSettings(type: AppSettingsType.notification);
    } on Exception {
      // Sebagian sistem hanya punya halaman pengaturan aplikasi umum.
      try {
        await AppSettings.openAppSettings();
      } on Exception {
        // Tidak ada pengaturan yang bisa dibuka; biarkan saja.
      }
    }
  }

  /// Plugin native hanya ada di Android/iOS. Di platform lain seluruh
  /// pemanggilan dilewati agar tidak melempar `MissingPluginException`.
  static Future<bool> _isSupported() async {
    try {
      await Permission.notification.status;
      return true;
    } on Exception {
      return false;
    }
  }
}
