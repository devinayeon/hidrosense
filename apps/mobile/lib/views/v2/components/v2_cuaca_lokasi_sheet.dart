import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/services/api_client.dart';
import '../../../data/services/device_locator.dart';
import '../../../models/weather_location.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_bottom_sheet.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_option_row.dart';
import '../widgets/v2_text_field.dart';

/// Sheet "Pilih lokasi" halaman Cuaca: lokasi pengguna lewat GPS, atau cari
/// wilayah dari provinsi turun ke desa/kelurahan.
///
/// Menutup dengan [WeatherLocation] pilihan; null bila dibatalkan. Sumber
/// daftar wilayah dan GPS disuntikkan supaya sheet ini tidak tahu soal
/// jaringan dan bisa diuji sendiri.
class V2CuacaLokasiSheet extends StatefulWidget {
  const V2CuacaLokasiSheet({
    super.key,
    required this.current,
    required this.loadRegions,
    required this.locateDevice,
  });

  final WeatherLocation current;

  /// Daftar wilayah satu tingkat; [parentId] null hanya untuk provinsi.
  final Future<List<WeatherRegion>> Function(
    WeatherRegionLevel level,
    String? parentId,
  )
  loadRegions;

  /// Desa tempat pengguna berada sekarang (GPS lalu backend).
  final Future<WeatherLocation> Function() locateDevice;

  @override
  State<V2CuacaLokasiSheet> createState() => _V2CuacaLokasiSheetState();
}

class _V2CuacaLokasiSheetState extends State<V2CuacaLokasiSheet> {
  final TextEditingController _query = TextEditingController();
  final List<WeatherRegion> _path = [];
  WeatherRegionLevel _level = WeatherRegionLevel.province;
  List<WeatherRegion> _items = const [];
  bool _loading = true;
  String? _error;
  bool _locating = false;
  String? _locateError;

  /// Naik turun tingkat menjatuhkan jawaban lama yang datang terlambat.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _items = const [];
    });
    try {
      final items = await widget.loadRegions(
        _level,
        _path.isEmpty ? null : _path.last.id,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = 'Daftar wilayah belum bisa dimuat. Periksa internet.';
      });
    }
  }

  void _pick(WeatherRegion region) {
    final next = _level.next;
    if (next == null) {
      final adm4 = region.adm4;
      if (adm4 == null || _path.length < 3) return;
      Navigator.of(context).pop(
        WeatherLocation(
          adm4: adm4,
          province: _path[0].name,
          regency: _path[1].name,
          district: _path[2].name,
          village: region.name,
        ),
      );
      return;
    }
    _path.add(region);
    _level = next;
    _query.clear();
    _load();
  }

  void _back() {
    if (_path.isEmpty) return;
    _path.removeLast();
    _level = WeatherRegionLevel.values[_level.index - 1];
    _query.clear();
    _load();
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _locateError = null;
    });
    try {
      final location = await widget.locateDevice();
      if (!mounted) return;
      Navigator.of(context).pop(location);
    } on DeviceLocationException catch (error) {
      if (!mounted) return;
      setState(() {
        _locating = false;
        _locateError = switch (error.failure) {
          DeviceLocationFailure.serviceOff =>
            'GPS mati. Nyalakan lokasi, atau pilih wilayah di bawah.',
          DeviceLocationFailure.denied =>
            'Izin lokasi ditolak. Pilih wilayah di bawah.',
          DeviceLocationFailure.deniedForever =>
            'Izin lokasi dimatikan. Aktifkan di pengaturan, atau pilih wilayah di bawah.',
          DeviceLocationFailure.unavailable =>
            'Lokasi belum didapat. Coba lagi, atau pilih wilayah di bawah.',
        };
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _locating = false;
        _locateError = error is ApiException && error.status == 404
            ? 'Lokasi Anda tidak dikenali. Pilih wilayah di bawah.'
            : 'Lokasi belum bisa dicari. Periksa internet, atau pilih wilayah di bawah.';
      });
    }
  }

  List<WeatherRegion> get _visible {
    final query = _query.text.trim().toLowerCase();
    if (query.isEmpty) return _items;
    return [
      for (final item in _items)
        if (item.name.toLowerCase().contains(query)) item,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = math.max(240.0, MediaQuery.sizeOf(context).height * 0.55);
    return V2BottomSheet(
      title: 'Pilih lokasi',
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sekarang: ${widget.current.label}',
                style: V2Type.label.copyWith(color: V2Colors.muted),
              ),
              const SizedBox(height: V2Space.lg),
              V2Button(
                label: _locating ? 'Mencari lokasi...' : 'Gunakan lokasi saya',
                type: V2ButtonType.secondary,
                state: _locating ? V2ButtonState.loading : V2ButtonState.normal,
                onPressed: _locating ? null : _locate,
              ),
              if (_locateError != null) ...[
                const SizedBox(height: V2Space.sm),
                Text(
                  _locateError!,
                  style: V2Type.label.copyWith(color: V2Colors.red700),
                ),
              ],
              const SizedBox(height: V2Space.xl),
              _header(),
              const SizedBox(height: V2Space.md),
              V2TextField(
                label: 'Cari ${_level.label}',
                hint: 'Ketik nama',
                controller: _query,
              ),
              const SizedBox(height: V2Space.md),
              ..._body(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    if (_path.isEmpty) {
      return Text('Atau pilih wilayah', style: V2Type.bodyStrong);
    }
    return Row(
      children: [
        Expanded(
          child: Text(
            _path.map((region) => region.name).join(' › '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: V2Type.bodyStrong,
          ),
        ),
        const SizedBox(width: V2Space.sm),
        V2Button(
          label: 'Kembali',
          type: V2ButtonType.ghost,
          expand: false,
          onPressed: _back,
        ),
      ],
    );
  }

  List<Widget> _body() {
    if (_loading) {
      return const [
        Padding(
          padding: EdgeInsets.all(V2Space.xl),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_error != null) {
      return [
        Text(_error!, style: V2Type.body.copyWith(color: V2Colors.red700)),
        const SizedBox(height: V2Space.md),
        V2Button(
          label: 'Coba lagi',
          type: V2ButtonType.tertiary,
          onPressed: _load,
        ),
      ];
    }
    final rows = _visible;
    if (rows.isEmpty) {
      return [
        Text(
          'Tidak ada ${_level.label} yang cocok.',
          style: V2Type.body.copyWith(color: V2Colors.muted),
        ),
      ];
    }
    return [
      for (var index = 0; index < rows.length; index++) ...[
        if (index > 0) const SizedBox(height: V2Space.md),
        V2OptionRow(
          label: rows[index].name,
          state:
              _level == WeatherRegionLevel.village &&
                  rows[index].adm4 == widget.current.adm4
              ? V2OptionState.selected
              : V2OptionState.normal,
          onTap: () => _pick(rows[index]),
        ),
      ],
    ];
  }
}
