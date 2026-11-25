import 'dart:convert';

import '../../models/weather_location.dart';
import '../services/api_client.dart';
import '../services/local_kv_store.dart';

/// Lokasi cuaca pilihan pengguna dan daftar wilayah dari backend.
///
/// Lokasi disimpan per perangkat (bukan per akun): kebunnya ada di satu
/// tempat, dan tugas latar saran cuaca harian membacanya tanpa tahu siapa
/// yang masuk.
class WeatherLocationRepository {
  WeatherLocationRepository(this._api, this._store);

  final ApiClient _api;
  final Future<LocalKvStore?> Function() _store;

  static const _scope = 'device';
  static const _key = 'weather_location';

  /// Lokasi tersimpan, atau lokasi mitra bila belum pernah memilih. Dipakai
  /// juga oleh tugas latar yang tidak punya [ApiClient].
  static Future<WeatherLocation> savedOrDefault(
    Future<LocalKvStore?> Function() store,
  ) async {
    try {
      final raw = await (await store())?.get(_scope, _key);
      if (raw == null) return WeatherLocation.partner;
      return WeatherLocation.tryFromJson(jsonDecode(raw)) ??
          WeatherLocation.partner;
    } catch (_) {
      return WeatherLocation.partner;
    }
  }

  Future<WeatherLocation> current() => savedOrDefault(_store);

  Future<void> save(WeatherLocation location) async {
    await (await _store())?.set(_scope, _key, jsonEncode(location.toJson()));
  }

  /// Daftar wilayah satu tingkat; [parent] wajib kecuali untuk provinsi.
  Future<List<WeatherRegion>> regions(
    WeatherRegionLevel level, {
    String? parent,
  }) async {
    final response = await _api.get(
      'weather/regions',
      query: {'level': level.apiName, 'parent': ?parent},
    );
    final data = response['data'];
    if (data is! List) {
      throw const FormatException('Daftar wilayah tidak valid.');
    }
    return List.unmodifiable([
      for (final row in data)
        if (row is Map && row['id'] is String && row['name'] is String)
          WeatherRegion(
            id: row['id'] as String,
            name: row['name'] as String,
            adm4: row['adm4'] is String ? row['adm4'] as String : null,
          )
        else
          throw const FormatException('Baris wilayah tidak valid.'),
    ]);
  }

  /// Posisi GPS menjadi desa terdekat. Melempar [ApiException] `404
  /// LOCATION_NOT_FOUND` bila posisinya di luar Indonesia atau tak dikenali.
  Future<WeatherLocation> locate(double lat, double lon) async {
    final response = await _api.get(
      'weather/locate',
      query: {'lat': lat.toStringAsFixed(6), 'lon': lon.toStringAsFixed(6)},
    );
    final data = response['data'];
    final adm4 = data is Map ? data['adm4'] : null;
    final location = data is Map
        ? WeatherLocation.tryFromJson({...data, 'adm4': adm4})
        : null;
    if (location == null) {
      throw const FormatException('Lokasi dari layanan tidak valid.');
    }
    return location;
  }

  /// Prakiraan BMKG lewat backend (disimpan sementara di server, juga saat
  /// BMKG gangguan). Cadangan bila BMKG tidak terjangkau langsung dari HP.
  Future<Map<String, dynamic>> forecastViaServer(String adm4) async {
    final response = await _api.get('weather/forecast', query: {'adm4': adm4});
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Prakiraan dari layanan tidak valid.');
    }
    return data;
  }
}
