import 'dart:async';

import 'package:flutter/material.dart';

import '../components/v2_akun_action_bar.dart';
import '../components/v2_panen_chart_card.dart';
import '../components/v2_panen_data.dart';
import '../components/v2_panen_skeleton.dart';
import '../components/v2_semaian_assets.dart';
import '../components/v2_meja_data.dart';
import '../components/v2_panen_assets.dart';
import '../theme/v2_tokens.dart';
import '../v2_roles.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_badge.dart';
import '../widgets/v2_banner.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_chip.dart';
import '../widgets/v2_error_state.dart';
import '../widgets/v2_group_list.dart';
import '../widgets/v2_segmented.dart';
import '../widgets/v2_stock_item.dart';
import '../widgets/v2_tab_bar.dart';
import 'v2_meja_detail_page.dart';
import 'v2_panen_detail_page.dart';
import 'v2_panen_form_page.dart';
import 'v2_semaian_list_page.dart';

/// Keadaan daftar panen yang punya frame sendiri di page 07.
enum V2PanenState {
  /// Frame 7.1/7.2/7.6/7.7/7.15: daftar siap dibaca.
  ready,

  /// Frame 7.3: rangka kartu sebelum daftar tampil.
  loading,

  /// Frame 7.4: muat daftar gagal.
  error,
}

/// Tiga arah di dalam tab "Tanam"; Panen yang sedang dipilih.
const List<String> v2PanenSegmen = <String>['Semaian', 'Meja', 'Panen'];

/// Isi tab "Tanam" → segmen Panen (frame 7.1–7.7, 7.15) tanpa TabBar.
///
/// Urutan siap: judul "Tanam", segmen Semaian/Meja/Panen, chip
/// Estimasi/Riwayat, lalu daftar. Keadaan memuat dan gagal tidak menampilkan
/// chip maupun footer (frame 7.3/7.4).
class V2PanenTabView extends StatefulWidget {
  const V2PanenTabView({
    super.key,
    this.estimasi,
    this.riwayat,
    this.state = V2PanenState.ready,
    this.initialChipIndex = 0,
    this.estimasiLoading = false,
    this.riwayatLoading = false,
    this.toast,
    this.toastTone = V2ToastTone.info,
    this.offline = false,
    this.onSegmentChanged,
    this.onCatatPanen,
    this.onTapPanen,
    this.onLihatSemaian,
    this.onRetry,
  });

  /// Baris estimasi; null berarti data contoh galeri.
  final List<V2PanenEstimasi>? estimasi;

  /// Baris riwayat; null berarti data contoh galeri.
  final List<V2PanenItem>? riwayat;

  final V2PanenState state;

  /// 0 Estimasi, 1 Riwayat.
  final int initialChipIndex;

  /// Estimasi belum bisa dinilai karena daftar batch masih dimuat; tampilkan
  /// kerangka di chip Estimasi, bukan pesan "belum ada tanaman".
  final bool estimasiLoading;

  /// Riwayat panen masih dimuat; tampilkan kerangka di chip Riwayat.
  final bool riwayatLoading;

  /// Toast yang melayang di atas tombol footer.
  final String? toast;
  final V2ToastTone toastTone;

  /// Menampilkan banner offline di bawah segmen (frame 7.15).
  final bool offline;

  final ValueChanged<int>? onSegmentChanged;
  final VoidCallback? onCatatPanen;
  final ValueChanged<V2PanenItem>? onTapPanen;

  /// Tombol "Lihat semaian" saat belum ada tanaman (frame 7.5).
  final VoidCallback? onLihatSemaian;

  /// Muat ulang saat daftar gagal; null berarti tombol tidak bereaksi.
  final VoidCallback? onRetry;

  @override
  State<V2PanenTabView> createState() => _V2PanenTabViewState();
}

class _V2PanenTabViewState extends State<V2PanenTabView> {
  late int _chip = widget.initialChipIndex;

  bool get _loading => widget.state == V2PanenState.loading;
  bool get _error => widget.state == V2PanenState.error;

  List<V2PanenEstimasi> get _estimasi => widget.estimasi ?? designEstimasiPanen;
  List<V2PanenItem> get _riwayat => widget.riwayat ?? designPanenRiwayat;

  /// Frame 7.5 tidak menampilkan chip sama sekali saat belum ada tanaman.
  /// Selama daftar batch masih dimuat, estimasi belum bisa dinilai.
  bool get _tanpaChip =>
      _estimasi.isEmpty && _chip == 0 && !widget.estimasiLoading;

  bool get _showFooter => !_loading && !_error;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _buildContent()),
        if (_showFooter) _buildFooter(),
      ],
    );
  }

  Widget _buildContent() {
    final kosongChip = _chip == 0 ? _estimasi.isEmpty : _riwayat.isEmpty;
    final menungguChip = _chip == 0
        ? widget.estimasiLoading
        : widget.riwayatLoading;

    if (_loading || (menungguChip && kosongChip)) {
      return _scroll(
        children: [
          _header(),
          const SizedBox(height: V2Space.lg),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: V2Space.xl),
            child: V2PanenSkeleton(),
          ),
        ],
      );
    }

    if (_error) {
      return _scroll(
        children: [
          _header(),
          const SizedBox(height: V2Space.lg),
          const SizedBox(height: V2Space.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
            child: V2ErrorState(
              title: 'Gagal memuat',
              body: 'Periksa internet, lalu coba lagi.',
              actionLabel: 'Coba lagi',
              onAction: widget.onRetry ?? () {},
              illustration: Image.asset(
                V2SemaianAssets.offlineNoInternet,
                width: 160,
                height: 160,
              ),
            ),
          ),
        ],
      );
    }

    if (_tanpaChip) {
      return _scroll(
        children: [
          _header(),
          const SizedBox(height: V2Space.lg),
          const SizedBox(height: 64),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
            child: V2ErrorState(
              title: 'Belum ada tanaman di meja',
              body: 'Pindahkan semaian ke meja dulu.',
              illustration: Image.asset(
                V2SemaianAssets.growingTable,
                width: 160,
                height: 160,
              ),
            ),
          ),
        ],
      );
    }

    return _scroll(
      children: [
        _header(),
        const SizedBox(height: V2Space.lg),
        _chips(),
        const SizedBox(height: V2Space.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
          child: _chip == 0 ? _isiEstimasi() : _isiRiwayat(),
        ),
      ],
    );
  }

  Widget _isiEstimasi() {
    return V2GroupList(
      children: [
        for (final item in _estimasi)
          V2StockItem(
            title: item.meja,
            subtitle: item.labelTanaman,
            quantity: item.labelHari,
            badge: item.siapPanen
                ? const V2Badge(
                    label: 'Siap panen',
                    status: V2BadgeStatus.success,
                  )
                : null,
            withCard: false,
            contentPadding: EdgeInsets.symmetric(
              horizontal: V2Space.lg,
              vertical: item.siapPanen ? V2Space.md : V2Space.lg,
            ),
            onTap: () => _bukaEstimasi(item),
          ),
      ],
    );
  }

  Widget _isiRiwayat() {
    if (_riwayat.isEmpty) {
      return Column(
        children: [
          const SizedBox(height: 48),
          V2ErrorState(
            title: 'Belum ada panen',
            body: 'Catat panen pertama.',
            illustration: Image.asset(
              V2PanenAssets.harvestLettuce,
              width: 160,
              height: 160,
            ),
          ),
        ],
      );
    }

    final grafik = v2GrafikPanenDari(_riwayat);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.offline) ...[
          // Grafik dari riwayat yang benar-benar tampil, bukan data contoh
          // (maks 3 tanggal terakhir, satu panen = satu tanggal).
          V2PanenChartCard(
            bars: grafik,
            caption: v2GrafikPanenKeterangan(grafik),
          ),
          const SizedBox(height: V2Space.sm),
        ],
        if (_riwayat.length == 1)
          V2StockItem(
            title: _riwayat.first.labelPanen,
            subtitle: _riwayat.first.meja,
            quantity: _riwayat.first.labelBerat,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: V2Space.lg,
              vertical: V2Space.lg,
            ),
            onTap: () => _bukaPanen(_riwayat.first),
          )
        else
          V2GroupList(
            children: [
              for (final item in _riwayat)
                V2StockItem(
                  title: item.labelPanen,
                  subtitle: item.meja,
                  quantity: item.labelBerat,
                  badge: item.antrean
                      ? const V2Badge(
                          label: 'Antrean',
                          status: V2BadgeStatus.pending,
                        )
                      : null,
                  withCard: false,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: V2Space.lg,
                    vertical: item.antrean ? V2Space.md : V2Space.lg,
                  ),
                  onTap: () => _bukaPanen(item),
                ),
            ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: V2Space.xl),
          child: V2ScreenHeader(title: 'Tanam'),
        ),
        const SizedBox(height: V2Space.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
          child: V2Segmented(
            labels: v2PanenSegmen,
            selectedIndex: 2,
            onChanged: widget.onSegmentChanged,
          ),
        ),
        if (widget.offline) ...[
          const SizedBox(height: V2Space.lg),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: V2Space.xl),
            child: V2Banner(message: 'Offline. Data tersimpan di HP.'),
          ),
        ],
      ],
    );
  }

  Widget _chips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
      child: Row(
        children: [
          for (var index = 0; index < labelChipPanen.length; index++) ...[
            if (index > 0) const SizedBox(width: V2Space.sm),
            V2Chip(
              label: labelChipPanen[index],
              selected: _chip == index,
              onTap: () => setState(() => _chip = index),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final kosong = _tanpaChip;
    return V2AkunActionBar(
      toast: widget.toast,
      toastTone: widget.toastTone,
      actions: [
        V2Button(
          label: kosong ? 'Lihat semaian' : 'Catat panen',
          onPressed: kosong
              ? (widget.onLihatSemaian ?? () {})
              : (widget.onCatatPanen ?? () {}),
        ),
      ],
    );
  }

  void _bukaEstimasi(V2PanenEstimasi estimasi) {
    if (estimasi.siapPanen) {
      Navigator.of(context).push<V2PanenItem>(
        V2PanenFormPage.route(
          meja: estimasi.meja,
          varietas: estimasi.varietas,
          jumlahTanaman: estimasi.jumlahTanaman,
        ),
      );
      return;
    }
    final meja = estimasi.meja == 'Meja A3' ? designMejaA3 : designMejaA2;
    Navigator.of(context).push(V2MejaDetailPage.route(meja));
  }

  void _bukaPanen(V2PanenItem item) {
    if (widget.onTapPanen != null) {
      widget.onTapPanen!(item);
      return;
    }
    Navigator.of(context).push<void>(V2PanenDetailPage.route(item));
  }
}

/// Halaman daftar panen lengkap dengan TabBar (frame 7.1–7.7, 7.15).
class V2PanenListPage extends StatefulWidget {
  const V2PanenListPage({
    super.key,
    this.estimasi,
    this.riwayat,
    this.role = V2BerandaRole.petani,
    this.state = V2PanenState.ready,
    this.initialChipIndex = 0,
    this.toast,
    this.toastTone = V2ToastTone.info,
    this.offline = false,
  });

  /// Frame `7.1 Panen, estimasi (Petani)`.
  const V2PanenListPage.petani({Key? key}) : this(key: key);

  /// Frame `7.2 Panen, estimasi (Pegawai)`.
  const V2PanenListPage.pegawai({Key? key})
    : this(key: key, role: V2BerandaRole.pegawai);

  /// Frame `7.3 Memuat panen`.
  const V2PanenListPage.memuat({Key? key})
    : this(key: key, state: V2PanenState.loading);

  /// Frame `7.4 Gagal memuat panen`.
  const V2PanenListPage.gagal({Key? key})
    : this(key: key, state: V2PanenState.error);

  /// Frame `7.5 Belum ada tanaman di meja`.
  const V2PanenListPage.kosong({Key? key})
    : this(key: key, estimasi: const <V2PanenEstimasi>[]);

  /// Frame `7.6 Panen, riwayat`.
  const V2PanenListPage.riwayat({Key? key})
    : this(key: key, initialChipIndex: 1);

  /// Frame `7.7 Riwayat panen kosong`.
  const V2PanenListPage.riwayatKosong({Key? key})
    : this(key: key, initialChipIndex: 1, riwayat: const <V2PanenItem>[]);

  /// Frame `7.15 Tersimpan di HP`: banner offline, baris antrean, dan toast.
  V2PanenListPage.offline({Key? key})
    : this(
        key: key,
        initialChipIndex: 1,
        riwayat: designPanenRiwayatAntrean,
        toast: 'Tersimpan di HP',
        offline: true,
      );

  final List<V2PanenEstimasi>? estimasi;
  final List<V2PanenItem>? riwayat;
  final V2BerandaRole role;
  final V2PanenState state;
  final int initialChipIndex;
  final String? toast;
  final V2ToastTone toastTone;
  final bool offline;

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const V2PanenListPage());

  @override
  State<V2PanenListPage> createState() => _V2PanenListPageState();
}

class _V2PanenListPageState extends State<V2PanenListPage> {
  late List<V2PanenItem> _riwayat = widget.riwayat ?? designPanenRiwayat;
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

  /// Buka form 7.8 lalu sisipkan panen baru di riwayat (frame 7.13/7.14).
  Future<void> _catatPanen() async {
    final item = await Navigator.of(
      context,
    ).push<V2PanenItem>(V2PanenFormPage.route());
    if (!mounted || item == null) return;
    setState(() {
      _riwayat = [item, ..._riwayat];
      _toast = widget.offline ? 'Tersimpan di HP' : 'Panen dicatat';
    });
    _scheduleToastDismiss();
  }

  void _lihatSemaian() {
    Navigator.of(context).push(V2SemaianListPage.route());
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
                child: V2PanenTabView(
                  estimasi: widget.estimasi,
                  riwayat: _riwayat,
                  state: widget.state,
                  initialChipIndex: widget.initialChipIndex,
                  toast: _toast,
                  toastTone: widget.toastTone,
                  offline: widget.offline,
                  onCatatPanen: _catatPanen,
                  onLihatSemaian: _lihatSemaian,
                ),
              ),
              V2TabBar(
                items: v2TabsFor(widget.role),
                activeIndex: v2TanamTabIndex,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
