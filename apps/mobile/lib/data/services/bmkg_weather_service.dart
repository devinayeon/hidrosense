import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/formatting.dart';
import '../../core/weather_rules.dart';
import '../../models/weather_model.dart';

const String _partnerAdm4 = '35.09.12.2002';
const String _bmkgEndpoint = 'https://api.bmkg.go.id/publik/prakiraan-cuaca';

class BmkgWeatherException implements Exception {
  const BmkgWeatherException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Klien prakiraan cuaca BMKG.
///
/// Kode wilayah default menunjuk ke Desa Sabrang, Kecamatan Ambulu,
/// Kabupaten Jember, lokasi mitra Hidro Selada. Kode ini bisa diganti saat
/// build dengan `--dart-define=BMKG_ADM4=...` bila lokasi mitra berubah.
class BmkgWeatherService {
  BmkgWeatherService({
    http.Client? client,
    this.adm4 = const String.fromEnvironment(
      'BMKG_ADM4',
      defaultValue: _partnerAdm4,
    ),
    Uri? endpoint,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _endpoint = endpoint ?? Uri.parse(_bmkgEndpoint);

  final http.Client _client;
  final bool _ownsClient;
  final Uri _endpoint;
  final String adm4;

  Future<WeatherData> fetchWeather({DateTime? fetchedAt}) async {
    final response = await _load(fetchedAt ?? DateTime.now());
    return response;
  }

  Future<WeatherData> _load(DateTime fetchedAt) async {
    http.Response response;
    try {
      response = await _client
          .get(
            _endpoint.replace(queryParameters: {'adm4': adm4}),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const BmkgWeatherException('Koneksi ke BMKG melebihi batas waktu.');
    } catch (_) {
      throw const BmkgWeatherException('Tidak dapat menghubungi layanan BMKG.');
    }

    if (response.statusCode != 200) {
      throw BmkgWeatherException(
        'Layanan BMKG sedang tidak tersedia (${response.statusCode}).',
      );
    }

    final Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException();
      }
      body = decoded;
    } on FormatException {
      throw const BmkgWeatherException(
        'Respons BMKG bukan data prakiraan yang valid.',
      );
    }

    final returnedAdm4 = body['lokasi'] is Map
        ? (body['lokasi'] as Map)['adm4']
        : null;
    if (returnedAdm4 is String && returnedAdm4 != adm4) {
      throw const BmkgWeatherException(
        'Lokasi prakiraan BMKG tidak sesuai dengan lokasi mitra.',
      );
    }

    return parseBmkgWeather(body, fetchedAt: fetchedAt);
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}

/// Mengubah respons API BMKG menjadi model yang dipakai UI HidroSense.
///
/// Parameter [fetchedAt] dipakai untuk memilih prakiraan terdekat dan menulis
/// waktu pembaruan. Semua waktu BMKG (`local_datetime`) diperlakukan sebagai
/// waktu lokal lokasi, bukan waktu perangkat.
WeatherData parseBmkgWeather(
  Map<String, dynamic> json, {
  required DateTime fetchedAt,
}) {
  final lokasi = _asMap(json['lokasi'], 'Lokasi BMKG tidak valid.');
  final data = json['data'];
  if (data is! List || data.isEmpty) {
    throw const BmkgWeatherException(
      'Data prakiraan cuaca BMKG tidak ditemukan.',
    );
  }

  final root = _asMap(data.first, 'Data prakiraan cuaca BMKG tidak valid.');
  final sourceLokasi = root['lokasi'] is Map
      ? _asMap(root['lokasi'], 'Lokasi prakiraan BMKG tidak valid.')
      : lokasi;
  final cuaca = root['cuaca'];
  if (cuaca is! List || cuaca.isEmpty) {
    throw const BmkgWeatherException(
      'Rincian prakiraan cuaca BMKG tidak ditemukan.',
    );
  }

  final slots = <_BmkgSlot>[];
  for (final day in cuaca) {
    if (day is! List) {
      throw const BmkgWeatherException(
        'Struktur prakiraan cuaca BMKG tidak valid.',
      );
    }
    for (final item in day) {
      slots.add(
        _parseSlot(_asMap(item, 'Rincian prakiraan cuaca BMKG tidak valid.')),
      );
    }
  }
  if (slots.isEmpty) {
    throw const BmkgWeatherException(
      'Rincian prakiraan cuaca BMKG tidak ditemukan.',
    );
  }
  slots.sort((a, b) => a.localDateTime.compareTo(b.localDateTime));

  final timezone = lokasi['timezone'] is String
      ? lokasi['timezone'] as String
      : 'Asia/Jakarta';
  final timezoneOffset = _parseTimezoneOffset(sourceLokasi['timezone']);
  final localNow = fetchedAt.toUtc().add(timezoneOffset);
  final current = _pickCurrent(slots, localNow);
  final todaySlots = slots
      .where((slot) => _sameDay(slot.localDateTime, localNow))
      .toList(growable: false);
  final effectiveToday = todaySlots.isEmpty
      ? slots
            .where(
              (slot) => _sameDay(slot.localDateTime, current.localDateTime),
            )
            .toList(growable: false)
      : todaySlots;
  final totalRainToday = effectiveToday.fold<double>(
    0,
    (total, slot) => total + slot.rainfallMm,
  );

  final days = <DateTime, List<_BmkgSlot>>{};
  for (final slot in slots) {
    final key = DateTime(
      slot.localDateTime.year,
      slot.localDateTime.month,
      slot.localDateTime.day,
    );
    days.putIfAbsent(key, () => <_BmkgSlot>[]).add(slot);
  }
  final dayKeys = days.keys.toList()..sort();

  final forecasts = dayKeys
      .map((day) {
        final daySlots = days[day]!;
        final maxTemperature = daySlots
            .map((slot) => slot.temperature)
            .reduce((a, b) => a > b ? a : b);
        final maxHumidity = daySlots
            .map((slot) => slot.humidity)
            .reduce((a, b) => a > b ? a : b);
        final maxWindSpeed = daySlots
            .map((slot) => slot.windSpeed)
            .reduce((a, b) => a > b ? a : b);
        final totalRain = daySlots.fold<double>(
          0,
          (total, slot) => total + slot.rainfallMm,
        );
        final descriptions = daySlots
            .map((slot) => slot.weatherDescription)
            .toSet()
            .toList(growable: false);
        final representative = _representativeSlot(daySlots);
        final rules = evaluateWeatherRules(
          maxTemperature: maxTemperature,
          maxHumidity: maxHumidity,
          totalRainfallMm: totalRain,
          maxWindSpeed: maxWindSpeed,
          weatherDescriptions: descriptions,
        );

        return PrakiraanHarian(
          waktu: _dayLabel(day, localNow),
          status: representative.weatherDescription,
          suhu: maxTemperature,
          ringkasanSaran: rules.summary,
          rekomendasiList: rules.actions,
        );
      })
      .toList(growable: false);

  final locationParts = [lokasi['desa'], lokasi['kecamatan'], lokasi['kotkab']]
      .whereType<String>()
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);

  return WeatherData(
    lokasi: 'KEBUN HIDRO SELADA',
    kota: locationParts.isEmpty
        ? 'Lokasi mitra HidroSense'
        : locationParts.join(', '),
    sumber: 'Sumber: BMKG • data prakiraan resmi',
    suhu: current.temperature,
    statusSuhu: _temperatureStatus(current.temperature),
    kelembapan: current.humidity,
    statusKelembapan: _humidityStatus(current.humidity),
    curahHujan: '${formatAngka(totalRainToday)} mm',
    estimasiHujan: current.weatherDescription,
    kecepatanAngin: current.windSpeed,
    arahAngin: _windDirection(current.windDirection),
    prakiraanHarian: forecasts,
    lastUpdated: _formatFetchedAt(localNow, timezone),
  );
}

class _BmkgSlot {
  const _BmkgSlot({
    required this.localDateTime,
    required this.temperature,
    required this.humidity,
    required this.rainfallMm,
    required this.weatherDescription,
    required this.windSpeed,
    required this.windDirection,
  });

  final DateTime localDateTime;
  final int temperature;
  final int humidity;
  final double rainfallMm;
  final String weatherDescription;
  final int windSpeed;
  final String? windDirection;
}

_BmkgSlot _parseSlot(Map<String, dynamic> raw) {
  final localRaw = raw['local_datetime'];
  final parsed = localRaw is String ? DateTime.tryParse(localRaw) : null;
  final localDateTime = parsed == null
      ? null
      : DateTime.utc(
          parsed.year,
          parsed.month,
          parsed.day,
          parsed.hour,
          parsed.minute,
          parsed.second,
        );
  final weatherDescription = raw['weather_desc'];
  final temperature = _asInt(raw['t']);
  final humidity = _asInt(raw['hu']);

  if (localDateTime == null ||
      weatherDescription is! String ||
      weatherDescription.trim().isEmpty ||
      temperature == null ||
      humidity == null) {
    throw const BmkgWeatherException(
      'Rincian prakiraan cuaca BMKG tidak lengkap.',
    );
  }

  return _BmkgSlot(
    localDateTime: localDateTime,
    temperature: temperature,
    humidity: humidity,
    rainfallMm: _asDouble(raw['tp']) ?? 0,
    weatherDescription: weatherDescription.trim(),
    windSpeed: _asInt(raw['ws']) ?? 0,
    windDirection: raw['wd'] is String ? raw['wd'] as String : null,
  );
}

_BmkgSlot _pickCurrent(List<_BmkgSlot> slots, DateTime localNow) {
  final cutoff = localNow.subtract(const Duration(hours: 1));
  for (final slot in slots) {
    if (!slot.localDateTime.isBefore(cutoff)) return slot;
  }
  return slots.last;
}

_BmkgSlot _representativeSlot(List<_BmkgSlot> slots) {
  for (final slot in slots) {
    final description = slot.weatherDescription.toLowerCase();
    if (description.contains('hujan') ||
        description.contains('badai') ||
        description.contains('petir')) {
      return slot;
    }
  }
  return slots.reduce((a, b) {
    final aDistance = (a.localDateTime.hour - 12).abs();
    final bDistance = (b.localDateTime.hour - 12).abs();
    return aDistance <= bDistance ? a : b;
  });
}

String _dayLabel(DateTime day, DateTime localNow) {
  final today = DateTime(localNow.year, localNow.month, localNow.day);
  final target = DateTime(day.year, day.month, day.day);
  final difference = target.difference(today).inDays;
  final date = formatTanggalIndo(day, singkat: true);

  if (difference == 0) return 'Hari Ini • $date';
  if (difference == 1) return 'Besok • $date';
  const names = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];
  return '${names[day.weekday - 1]} • $date';
}

String _temperatureStatus(int temperature) {
  if (temperature < 20) return 'Dingin';
  if (temperature <= 29) return 'Stabil';
  if (temperature <= 32) return 'Hangat';
  return 'Panas';
}

String _humidityStatus(int humidity) {
  if (humidity < 60) return 'Kering';
  if (humidity <= 80) return 'Normal';
  if (humidity <= 90) return 'Lembap';
  return 'Sangat Lembap';
}

String _windDirection(String? direction) {
  final label = switch (direction?.toUpperCase()) {
    'N' => 'Utara',
    'NE' => 'Timur Laut',
    'E' => 'Timur',
    'SE' => 'Tenggara',
    'S' => 'Selatan',
    'SW' => 'Barat Daya',
    'W' => 'Barat',
    'NW' => 'Barat Laut',
    _ => null,
  };
  return label == null ? 'Arah angin tidak tersedia' : 'Dari arah $label';
}

String _formatFetchedAt(DateTime localNow, String timezone) {
  final hour = localNow.hour.toString().padLeft(2, '0');
  final minute = localNow.minute.toString().padLeft(2, '0');
  final zone = timezone.contains('Makassar')
      ? 'WITA'
      : timezone.contains('Jayapura')
      ? 'WIT'
      : 'WIB';
  return '${formatTanggalIndo(localNow, singkat: true)} • $hour:$minute $zone';
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

Duration _parseTimezoneOffset(Object? raw) {
  if (raw is String && RegExp(r'^[+-]\d{4}$').hasMatch(raw)) {
    final sign = raw.startsWith('-') ? -1 : 1;
    final hours = int.parse(raw.substring(1, 3));
    final minutes = int.parse(raw.substring(3, 5));
    return Duration(minutes: sign * (hours * 60 + minutes));
  }
  return const Duration(hours: 7);
}

Map<String, dynamic> _asMap(Object? value, String message) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw BmkgWeatherException(message);
}

int? _asInt(Object? value) {
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
