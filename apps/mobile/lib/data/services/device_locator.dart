import 'package:geolocator/geolocator.dart';

/// Mengapa posisi perangkat tidak bisa didapat; menentukan pesan ke pengguna.
enum DeviceLocationFailure {
  /// GPS/layanan lokasi di perangkat dimatikan.
  serviceOff,

  /// Izin ditolak kali ini; boleh diminta lagi.
  denied,

  /// Izin ditolak permanen; hanya bisa dibuka lewat pengaturan.
  deniedForever,

  /// Izin ada tetapi posisi tidak didapat (waktu habis, sinyal lemah).
  unavailable,
}

class DeviceLocationException implements Exception {
  const DeviceLocationException(this.failure);

  final DeviceLocationFailure failure;

  @override
  String toString() => 'DeviceLocationException($failure)';
}

/// Posisi perangkat saat ini.
abstract interface class DeviceLocator {
  Future<({double lat, double lon})> currentPosition();
}

/// Posisi lewat paket `geolocator`. Ketelitian rendah cukup: yang dicari
/// hanya desa, bukan titik tepat, dan itu lebih cepat serta hemat baterai.
class GeolocatorDeviceLocator implements DeviceLocator {
  const GeolocatorDeviceLocator();

  @override
  Future<({double lat, double lon})> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const DeviceLocationException(DeviceLocationFailure.serviceOff);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const DeviceLocationException(DeviceLocationFailure.deniedForever);
    }
    if (permission == LocationPermission.denied) {
      throw const DeviceLocationException(DeviceLocationFailure.denied);
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return (lat: position.latitude, lon: position.longitude);
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return (lat: last.latitude, lon: last.longitude);
      throw const DeviceLocationException(DeviceLocationFailure.unavailable);
    }
  }
}
