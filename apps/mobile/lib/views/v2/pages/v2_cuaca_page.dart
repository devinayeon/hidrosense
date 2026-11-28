import 'package:flutter/material.dart';

import '../components/v2_cuaca_assets.dart';
import '../components/v2_cuaca_cards.dart';
import '../components/v2_cuaca_data.dart';
import '../components/v2_cuaca_skeleton.dart';
import '../../../models/weather_model.dart';
import '../components/v2_rawat_ai_banner.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_banner.dart';
import '../widgets/v2_bottom_sheet.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_error_state.dart';
import '../widgets/v2_icon.dart';
import '../widgets/v2_option_row.dart';
import '../widgets/v2_refresh_button.dart';
import '../widgets/v2_segmented.dart';
import '../widgets/v2_stock_item.dart';

/// Segmen di page “10 Cuaca BMKG” (component `Segmented3`).
enum V2CuacaTab {
  /// Frame 10.1/10.5/10.8: cuaca saat ini dan info tambahan.
  kondisi,

  /// Frame 10.2/10.9: prakiraan empat hari.
  prakiraan,

  /// Frame 10.3/10.4/10.10/10.11: saran perawatan dari AI.
  saran,
}

/// Halaman Cuaca BMKG (frame 10.1–10.11).
///
/// Semua keadaan memakai satu halaman: AppBar “Cuaca”, lokasi + segmen, lalu
/// isi sesuai tab. Saat [memuat] lokasi dan segmen diganti kerangka kartu
/// (10.6); saat [bmkgGagal] tampil `ErrorState` (10.7).
class V2CuacaPage extends StatefulWidget {
  const V2CuacaPage({
    super.key,
    this.tab = V2CuacaTab.kondisi,
    this.memuat = false,
    this.bmkgGagal = false,
    this.offline = false,
    this.saranKosong = false,
    this.saranGagal = false,
    this.bukaSheet = false,
    this.data,
    this.lokasiList,
    this.lokasiLabel,
    this.onRetry,
    this.onRefresh,
    this.onPilihLokasi,
  });

  /// Frame 10.1 Cuaca, kondisi.
  const V2CuacaPage.kondisi({Key? key}) : this(key: key);

  /// Frame 10.2 Cuaca, prakiraan.
  const V2CuacaPage.prakiraan({Key? key})
    : this(key: key, tab: V2CuacaTab.prakiraan);

  /// Frame 10.3 Saran perawatan.
  const V2CuacaPage.saran({Key? key}) : this(key: key, tab: V2CuacaTab.saran);

  /// Frame 10.4 Saran kosong.
  const V2CuacaPage.saranKosong({Key? key})
    : this(key: key, tab: V2CuacaTab.saran, saranKosong: true);

  /// Frame 10.5 Pilih lokasi (sheet langsung terbuka).
  const V2CuacaPage.pilihLokasi({Key? key}) : this(key: key, bukaSheet: true);

  /// Frame 10.6 Memuat cuaca.
  const V2CuacaPage.memuat({Key? key}) : this(key: key, memuat: true);

  /// Frame 10.7 BMKG tidak tersedia.
  const V2CuacaPage.bmkgGagal({Key? key}) : this(key: key, bmkgGagal: true);

  /// Frame 10.8 Cuaca tanpa internet.
  const V2CuacaPage.tanpaInternet({Key? key}) : this(key: key, offline: true);

  /// Frame 10.9 Prakiraan tanpa internet.
  const V2CuacaPage.prakiraanTanpaInternet({Key? key})
    : this(key: key, tab: V2CuacaTab.prakiraan, offline: true);

  /// Frame 10.10 Saran tanpa internet.
  const V2CuacaPage.saranTanpaInternet({Key? key})
    : this(key: key, tab: V2CuacaTab.saran, offline: true);

  /// Frame 10.11 Saran AI tidak tersedia.
  const V2CuacaPage.saranGagal({Key? key})
    : this(key: key, tab: V2CuacaTab.saran, saranGagal: true);

  final V2CuacaTab tab;
  final bool memuat;
  final bool bmkgGagal;
  final bool offline;
  final bool saranKosong;
  final bool saranGagal;
  final bool bukaSheet;

  /// Data BMKG nyata; null berarti kartu contoh galeri.
  final WeatherData? data;

  /// Lokasi yang bisa dipilih; null berarti tiga lokasi contoh.
  final List<V2CuacaLokasi>? lokasiList;

  /// Label lokasi di atas segmen; null berarti lokasi contoh terpilih.
  final String? lokasiLabel;

  /// Muat ulang BMKG nyata; null berarti jeda contoh 700 ms.
  final Future<void> Function()? onRetry;

  /// Tarik-turun dan tombol "Muat ulang" di header; null berarti memakai
  /// [onRetry] bila ada, kalau tidak keduanya disembunyikan.
  final Future<void> Function()? onRefresh;

  /// Membuka pemilih lokasi nyata (GPS atau cari wilayah). Null berarti
  /// sheet tiga lokasi contoh milik galeri.
  final Future<void> Function(BuildContext context)? onPilihLokasi;

  static Route<void> route() => MaterialPageRoute<void>(
    settings: const RouteSettings(name: 'v2-cuaca'),
    builder: (_) => const V2CuacaPage(),
  );

  @override
  State<V2CuacaPage> createState() => _V2CuacaPageState();
}

class _V2CuacaPageState extends State<V2CuacaPage> {
  late V2CuacaTab _tab = widget.tab;
  late bool _memuat = widget.memuat;
  late bool _bmkgGagal = widget.bmkgGagal;
  late bool _saranGagal = widget.saranGagal;
  var _lokasi = 0;

  @override
  void initState() {
    super.initState();
    if (widget.bukaSheet) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _bukaSheet());
    }
  }

  @override
  void didUpdateWidget(covariant V2CuacaPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data ||
        oldWidget.memuat != widget.memuat ||
        oldWidget.bmkgGagal != widget.bmkgGagal) {
      _memuat = widget.memuat;
      _bmkgGagal = widget.bmkgGagal;
    }
  }

  List<V2CuacaLokasi> get _daftarLokasi => widget.lokasiList?.isNotEmpty == true
      ? widget.lokasiList!
      : designCuacaLokasi;

  V2CuacaSekarang get _sekarang {
    final data = widget.data;
    if (data == null) return designCuacaSekarang;
    return V2CuacaSekarang(
      suhu: '${data.suhu}°C',
      kondisi: data.estimasiHujan,
      catatan: data.statusSuhu,
      kelembapan: '${data.kelembapan}%',
      angin: '${data.kecepatanAngin} km/jam ${data.arahAngin}',
      hujan: data.curahHujan,
    );
  }

  List<V2CuacaHarian> get _prakiraanData {
    final data = widget.data;
    if (data == null) return designCuacaPrakiraan;
    return data.prakiraanHarian
        .map(
          (hari) => V2CuacaHarian(
            hari: hari.waktu,
            kondisi: hari.status,
            suhu: '${hari.suhu}°C',
          ),
        )
        .toList();
  }

  List<V2CuacaSaran> get _saranData {
    final data = widget.data;
    if (data == null) return designCuacaSaran;
    final hasil = <V2CuacaSaran>[];
    for (final hari in data.prakiraanHarian) {
      for (final saran in hari.rekomendasiList) {
        if (hasil.any((row) => row.judul == saran.judul)) continue;
        hasil.add(
          V2CuacaSaran(
            judul: saran.judul,
            isi: saran.deskripsi,
            dasar: saran.alasan,
          ),
        );
      }
    }
    return hasil;
  }

  String get _labelLokasi => widget.lokasiLabel ?? _daftarLokasi[_lokasi].label;

  String get _captionLokasi {
    if (widget.offline) return v2CuacaDataTerakhir;
    final data = widget.data;
    if (data == null) return v2CuacaDiperbarui;
    return 'Diperbarui ${data.lastUpdated}. ${data.sumber}';
  }

  Future<void> _bukaSheet() async {
    if (!mounted) return;
    final pilihLokasi = widget.onPilihLokasi;
    if (pilihLokasi != null) {
      await pilihLokasi(context);
      return;
    }
    // Sheet lokasi memakai scrim 60% seperti frame 10.5, bukan 35% bawaan
    // `showV2BottomSheet`.
    final pilihan = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: V2Colors.ink.withValues(alpha: 0.6),
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: _PilihLokasiSheet(lokasiAwal: _lokasi, lokasi: _daftarLokasi),
      ),
    );
    if (!mounted || pilihan == null) return;
    if (pilihan == _lokasi) return;
    // Catatan alur 10.5: memilih lokasi menutup sheet lalu memuat ulang.
    setState(() {
      _lokasi = pilihan;
      _tab = V2CuacaTab.kondisi;
      _memuat = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _memuat = false);
  }

  Future<void> _muatUlangBmkg() async {
    setState(() => _memuat = true);
    final retry = widget.onRetry;
    if (retry != null) {
      try {
        await retry();
      } finally {
        if (mounted) {
          setState(() {
            _memuat = false;
            _bmkgGagal = false;
          });
        }
      }
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _memuat = false;
      _bmkgGagal = false;
    });
  }

  /// Ada sumber muat ulang nyata; galeri murni tanpa keduanya tidak
  /// menampilkan tombol maupun tarik-turun.
  bool get _canRefresh => widget.onRefresh != null || widget.onRetry != null;

  /// Tarik-turun/tombol: pakai callback khusus bila ada, kalau tidak muat ulang
  /// BMKG seperti tombol "Coba lagi".
  Future<void> _refresh() async {
    final refresh = widget.onRefresh;
    if (refresh != null) return refresh();
    return _muatUlangBmkg();
  }

  /// Tarik-turun hanya aktif bila ada sumber data nyata.
  Widget _refreshable(Widget child) {
    if (!_canRefresh) return child;
    return RefreshIndicator(onRefresh: _refresh, child: child);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: V2Theme.light,
      child: Scaffold(
        backgroundColor: V2Colors.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              V2AppBar(
                title: 'Cuaca',
                onBack: () => Navigator.of(context).maybePop(),
                trailing: V2RefreshButton(
                  onRefresh: _canRefresh ? _refresh : null,
                ),
              ),
              Expanded(
                child: _refreshable(
                  SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      V2Space.xl,
                      V2Space.sm,
                      V2Space.xl,
                      V2Space.xl,
                    ),
                    child: _isi(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _isi(BuildContext context) {
    if (_memuat) return const V2CuacaSkeleton();
    if (_bmkgGagal) {
      return Padding(
        padding: const EdgeInsets.only(top: V2Space.xl),
        child: V2ErrorState(
          title: 'Cuaca BMKG tidak tersedia',
          body: 'BMKG sedang bermasalah. Coba lagi nanti.',
          actionLabel: 'Coba lagi',
          onAction: _muatUlangBmkg,
          illustration: Image.asset(
            V2CuacaAssets.offlineNoInternet,
            width: 160,
            height: 160,
            filterQuality: FilterQuality.high,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.offline) ...[
          const V2Banner(message: 'Offline. Data tersimpan di HP.'),
          const SizedBox(height: V2Space.lg),
        ],
        V2CuacaLokasiHeader(
          lokasi: _labelLokasi,
          caption: _captionLokasi,
          onTap: _bukaSheet,
        ),
        const SizedBox(height: V2Space.lg),
        V2Segmented(
          labels: const <String>['Kondisi', 'Prakiraan', 'Saran'],
          selectedIndex: _tab.index,
          onChanged: (index) => setState(() => _tab = V2CuacaTab.values[index]),
        ),
        const SizedBox(height: V2Space.lg),
        ..._isiTab(context),
      ],
    );
  }

  List<Widget> _isiTab(BuildContext context) {
    return switch (_tab) {
      V2CuacaTab.kondisi => _kondisi(),
      V2CuacaTab.prakiraan => _prakiraan(),
      V2CuacaTab.saran => _saran(),
    };
  }

  List<Widget> _kondisi() {
    return <Widget>[
      V2CuacaSekarangCard(data: _sekarang),
      const SizedBox(height: V2Space.lg),
      V2CuacaInfoCard(data: _sekarang),
      if (widget.offline) ...[
        const SizedBox(height: V2Space.lg),
        Text(
          v2CuacaSaranButuhInternet,
          style: V2Type.label.copyWith(color: V2Colors.muted),
        ),
      ],
    ];
  }

  List<Widget> _prakiraan() {
    final daftar = _prakiraanData;
    return <Widget>[
      for (var index = 0; index < daftar.length; index++) ...[
        if (index > 0) const SizedBox(height: V2Space.lg),
        V2StockItem(
          title: daftar[index].hari,
          subtitle: daftar[index].kondisi,
          quantity: daftar[index].suhu,
          icon: V2IconName.cloud,
          iconSize: 24,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: V2Space.lg,
            vertical: V2Space.lg,
          ),
        ),
      ],
    ];
  }

  List<Widget> _saran() {
    if (widget.offline) {
      return <Widget>[
        const V2CuacaCatatanCard(
          title: 'Saran butuh internet',
          body: 'Sambungkan internet. Cuaca terakhir ada di Kondisi.',
        ),
      ];
    }
    if (_saranGagal) {
      return <Widget>[
        V2CuacaCatatanCard(
          title: 'Saran belum bisa dimuat',
          body: 'Cuaca tetap bisa dilihat di Kondisi.',
          actionLabel: 'Coba lagi',
          onAction: () => setState(() => _saranGagal = false),
        ),
      ];
    }
    final daftar = _saranData;
    if (widget.saranKosong || daftar.isEmpty) {
      return const <Widget>[
        V2CuacaCatatanCard(
          title: 'Tidak ada saran khusus',
          body: 'Cuaca aman untuk perawatan biasa.',
        ),
      ];
    }

    return <Widget>[
      const V2RawatAiBanner(),
      for (final saran in daftar) ...[
        const SizedBox(height: V2Space.lg),
        V2CuacaSaranCard(saran: saran),
      ],
    ];
  }
}

/// Isi sheet 10.5: tiga lokasi dan tombol “Pilih”.
class _PilihLokasiSheet extends StatefulWidget {
  const _PilihLokasiSheet({required this.lokasiAwal, required this.lokasi});

  final int lokasiAwal;
  final List<V2CuacaLokasi> lokasi;

  @override
  State<_PilihLokasiSheet> createState() => _PilihLokasiSheetState();
}

class _PilihLokasiSheetState extends State<_PilihLokasiSheet> {
  late var _pilih = widget.lokasiAwal;

  @override
  Widget build(BuildContext context) {
    return V2BottomSheet(
      title: 'Pilih lokasi',
      actions: V2Button(
        label: 'Pilih',
        onPressed: () => Navigator.of(context).pop(_pilih),
      ),
      child: Column(
        children: [
          for (var index = 0; index < widget.lokasi.length; index++) ...[
            if (index > 0) const SizedBox(height: V2Space.lg),
            V2OptionRow(
              label: widget.lokasi[index].label,
              state: index == _pilih
                  ? V2OptionState.selected
                  : V2OptionState.normal,
              onTap: () => setState(() => _pilih = index),
            ),
          ],
        ],
      ),
    );
  }
}
