import 'dart:async';

import 'package:flutter/material.dart';

import '../components/v2_rawat_assets.dart';
import '../components/v2_rawat_data.dart';
import '../components/v2_rawat_foto_card.dart';
import '../theme/v2_tokens.dart';
import '../v2_roles.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_badge.dart';
import '../widgets/v2_banner.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_error_state.dart';
import '../widgets/v2_group_list.dart';
import '../widgets/v2_icon.dart';
import '../widgets/v2_list_item.dart';
import '../widgets/v2_skeleton.dart';
import '../widgets/v2_stock_item.dart';
import '../widgets/v2_tab_bar.dart';
import '../components/v2_akun_action_bar.dart';
import 'v2_cuaca_page.dart';
import 'v2_rawat_detail_page.dart';
import 'v2_rawat_foto_page.dart';

/// Keadaan tab Rawat yang punya frame sendiri di page 09.
enum V2RawatState {
  /// Frame 9.1/9.4/9.11/9.25: daftar siap dibaca.
  ready,

  /// Frame 9.2: empat rangka baris sebelum daftar tampil.
  loading,

  /// Frame 9.3: muat daftar gagal.
  error,
}

/// Isi tab “Rawat” (frame 9.1–9.4, 9.11, 9.25) tanpa TabBar.
///
/// Urutan siap: judul “Rawat”, kartu “Cek hama”, baris cuaca, lalu riwayat.
/// Saat offline [offline] menyala, kartu dan cuaca diganti banner dan riwayat
/// memuat baris antrean (9.11/9.25).
class V2RawatTabView extends StatefulWidget {
  const V2RawatTabView({
    super.key,
    this.riwayat,
    this.state = V2RawatState.ready,
    this.offline = false,
    this.toast,
    this.toastTone = V2ToastTone.info,
    this.onFotoTanaman,
    this.onTapItem,
    this.onRetry,
    this.onOpenCuaca,
  });

  /// Baris riwayat; null berarti data contoh galeri.
  final List<V2RawatItem>? riwayat;

  final V2RawatState state;

  /// Menampilkan banner “Offline. Data tersimpan di HP.” (frame 9.11/9.25).
  final bool offline;

  /// Toast yang melayang di atas tombol footer (frame 9.11).
  final String? toast;
  final V2ToastTone toastTone;

  final VoidCallback? onFotoTanaman;
  final ValueChanged<V2RawatItem>? onTapItem;

  /// Muat ulang saat daftar gagal; null berarti tombol tidak bereaksi.
  final VoidCallback? onRetry;

  /// Membuka halaman cuaca; null berarti halaman contoh galeri.
  final VoidCallback? onOpenCuaca;

  @override
  State<V2RawatTabView> createState() => _V2RawatTabViewState();
}

class _V2RawatTabViewState extends State<V2RawatTabView> {
  bool get _loading => widget.state == V2RawatState.loading;
  bool get _error => widget.state == V2RawatState.error;

  List<V2RawatItem> get _riwayat => widget.riwayat ?? designRawatRiwayat;

  bool get _kosong => _riwayat.isEmpty && !widget.offline;

  bool get _showFooter => !_loading && !_error;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _buildContent()),
        if (_showFooter) _footer(),
      ],
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return _scroll(
        children: [
          _header(),
          const SizedBox(height: V2Space.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
            child: Column(
              children: [
                for (var index = 0; index < 4; index++) ...[
                  if (index > 0) const SizedBox(height: V2Space.lg),
                  const _BarisRangka(),
                ],
              ],
            ),
          ),
        ],
      );
    }

    if (_error) {
      return _scroll(
        children: [
          _header(),
          const SizedBox(height: V2Space.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
            child: V2ErrorState(
              title: 'Gagal memuat',
              body: 'Periksa internet, lalu coba lagi.',
              actionLabel: 'Coba lagi',
              onAction: widget.onRetry ?? () {},
              illustration: Image.asset(
                V2RawatAssets.offlineNoInternet,
                width: 160,
                height: 160,
              ),
            ),
          ),
        ],
      );
    }

    if (_kosong) {
      return _scroll(
        children: [
          _header(),
          const SizedBox(height: V2Space.lg),
          const _KeadaanKosong(),
        ],
      );
    }

    return _scroll(
      children: [
        _header(),
        const SizedBox(height: V2Space.lg),
        if (widget.offline)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: V2Space.xl),
            child: V2Banner(message: 'Offline. Data tersimpan di HP.'),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
            child: V2RawatCekHamaCard(onTap: widget.onFotoTanaman ?? () {}),
          ),
          const SizedBox(height: V2Space.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
            child: V2ListItem(
              title: 'Cuaca dan saran',
              subtitle: 'Berawan, 29°C',
              icon: V2IconName.cloud,
              onTap:
                  widget.onOpenCuaca ??
                  () => Navigator.of(context).push(V2CuacaPage.route()),
            ),
          ),
        ],
        const SizedBox(height: V2Space.lg),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: V2Space.xl),
          child: Text('Riwayat perawatan', style: V2Type.h2),
        ),
        const SizedBox(height: V2Space.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
          child: V2GroupList(
            children: [
              for (final item in _riwayat)
                V2StockItem(
                  title: item.judul,
                  subtitle: item.meja,
                  quantity: item.labelTanggal,
                  icon: item.foto ? V2IconName.camera : V2IconName.care,
                  iconSize: 24,
                  badge: item.antrean
                      ? const V2Badge(
                          label: 'Antrean',
                          status: V2BadgeStatus.pending,
                        )
                      : const V2Badge(
                          label: 'Selesai',
                          status: V2BadgeStatus.success,
                        ),
                  withCard: false,
                  onTap: () => _bukaItem(item),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _scroll({required List<Widget> children}) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.only(top: V2Space.lg, bottom: V2Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _header() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: V2Space.xl),
      child: V2ScreenHeader(title: 'Rawat'),
    );
  }

  Widget _footer() {
    return V2AkunActionBar(
      toast: widget.toast,
      toastTone: widget.toastTone,
      actions: [
        V2Button(
          label: 'Foto tanaman',
          onPressed: widget.onFotoTanaman ?? () {},
        ),
      ],
    );
  }

  void _bukaItem(V2RawatItem item) {
    if (widget.onTapItem != null) {
      widget.onTapItem!(item);
      return;
    }
    if (item.foto) return;
    Navigator.of(context).push<void>(V2RawatDetailPage.route(item));
  }
}

/// Empat rangka baris 80 dengan avatar 48 (frame 9.2).
class _BarisRangka extends StatelessWidget {
  const _BarisRangka();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(
        horizontal: V2Space.lg,
        vertical: V2Space.lg,
      ),
      decoration: BoxDecoration(
        color: V2Colors.white,
        borderRadius: BorderRadius.circular(V2Radius.card),
      ),
      child: Row(
        children: [
          const V2Skeleton.circle(size: 48),
          const SizedBox(width: V2Space.lg),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              V2Skeleton.line(width: 180, height: 16),
              SizedBox(height: V2Space.sm),
              V2Skeleton.line(width: 120, height: 16),
            ],
          ),
        ],
      ),
    );
  }
}

/// Keadaan “Belum ada perawatan” (frame 9.4): ilustrasi 160, judul, ajakan.
class _KeadaanKosong extends StatelessWidget {
  const _KeadaanKosong();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
      child: Column(
        children: [
          const SizedBox(height: 48),
          Image.asset(V2RawatAssets.itemPlantCare, width: 160, height: 160),
          const SizedBox(height: V2Space.lg),
          Text(
            'Belum ada perawatan',
            textAlign: TextAlign.center,
            style: V2Type.h1,
          ),
          const SizedBox(height: V2Space.lg),
          Text(
            'Foto daun untuk cek hama.',
            textAlign: TextAlign.center,
            style: V2Type.body.copyWith(color: V2Colors.muted),
          ),
        ],
      ),
    );
  }
}

/// Halaman tab Rawat lengkap dengan TabBar (frame 9.1–9.4, 9.11, 9.25).
class V2RawatListPage extends StatefulWidget {
  const V2RawatListPage({
    super.key,
    this.riwayat,
    this.state = V2RawatState.ready,
    this.offline = false,
    this.toast,
    this.toastTone = V2ToastTone.info,
  });

  /// Frame `9.1 Rawat (Petani)`.
  const V2RawatListPage.petani({Key? key}) : this(key: key);

  /// Frame `9.2 Memuat rawat`.
  const V2RawatListPage.memuat({Key? key})
    : this(key: key, state: V2RawatState.loading);

  /// Frame `9.3 Gagal memuat rawat`.
  const V2RawatListPage.gagal({Key? key})
    : this(key: key, state: V2RawatState.error);

  /// Frame `9.4 Belum ada perawatan`.
  const V2RawatListPage.kosong({Key? key})
    : this(key: key, riwayat: const <V2RawatItem>[]);

  /// Frame `9.11 Foto tersimpan (antrean)`.
  V2RawatListPage.fotoTersimpan({Key? key})
    : this(
        key: key,
        riwayat: designRawatRiwayatFoto,
        offline: true,
        toast: 'Foto tersimpan di HP',
      );

  /// Frame `9.25 Perawatan tersimpan di HP`.
  V2RawatListPage.tersimpanHp({Key? key})
    : this(key: key, riwayat: designRawatRiwayatAntrean, offline: true);

  final List<V2RawatItem>? riwayat;
  final V2RawatState state;
  final bool offline;
  final String? toast;
  final V2ToastTone toastTone;

  static Route<void> route() => MaterialPageRoute<void>(
    settings: const RouteSettings(name: 'v2-rawat-list'),
    builder: (_) => const V2RawatListPage(),
  );

  @override
  State<V2RawatListPage> createState() => _V2RawatListPageState();
}

class _V2RawatListPageState extends State<V2RawatListPage> {
  late List<V2RawatItem> _riwayat = widget.riwayat ?? designRawatRiwayat;
  late bool _offline = widget.offline;
  late String? _toast = widget.toast;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    if (_toast != null) _scheduleToastDismiss();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  void _scheduleToastDismiss() {
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  Future<void> _fotoTanaman() async {
    await Navigator.of(context).push<V2RawatItem>(
      V2RawatFotoPage.route(
        onSaved: (item) {
          if (!mounted) return;
          setState(() {
            _riwayat = <V2RawatItem>[item, ..._riwayat];
            _offline = _offline || item.antrean;
            // Frame 9.11 memunculkan toast setelah foto disimpan di HP;
            // perawatan yang langsung terkirim (9.25) tanpa toast.
            _toast = item.foto ? 'Foto tersimpan di HP' : null;
          });
          if (_toast != null) _scheduleToastDismiss();
        },
      ),
    );
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
              Expanded(
                child: V2RawatTabView(
                  riwayat: _riwayat,
                  state: widget.state,
                  offline: _offline,
                  toast: _toast,
                  toastTone: widget.toastTone,
                  onFotoTanaman: _fotoTanaman,
                ),
              ),
              const V2TabBar(items: v2PetaniTabs, activeIndex: v2RawatTabIndex),
            ],
          ),
        ),
      ),
    );
  }
}
