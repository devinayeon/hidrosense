import 'dart:async';

import 'package:flutter/material.dart';

import '../components/v2_penjualan_assets.dart';
import '../components/v2_penjualan_data.dart';
import '../components/v2_penjualan_row.dart';
import '../components/v2_penjualan_skeleton.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_action_bar.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_badge.dart';
import '../widgets/v2_banner.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_chip.dart';
import '../widgets/v2_error_state.dart';
import '../widgets/v2_group_list.dart';
import '../widgets/v2_icon.dart';
import '../widgets/v2_icon_button.dart';
import '../widgets/v2_summary_card.dart';
import 'v2_penjualan_detail_page.dart';
import 'v2_penjualan_form_page.dart';
import 'v2_penjualan_summary_page.dart';

/// Keadaan daftar penjualan yang punya frame sendiri di page 08.
enum V2PenjualanListState {
  /// Frame 8.1/8.6: daftar siap.
  ready,

  /// Frame 8.2: rangka kartu sebelum daftar tampil.
  loading,

  /// Frame 8.3: muat daftar gagal.
  error,

  /// Frame 8.4: belum ada satu pun penjualan.
  empty,

  /// Frame 8.14: penjualan baru saja dicatat.
  created,

  /// Frame 8.16: perangkat offline, satu penjualan masih antre.
  offline,
}

/// Daftar penjualan: frame 8.1 (siap), 8.2 (memuat), 8.3 (gagal memuat),
/// 8.4 (kosong), 8.6 (saringan belum lunas), 8.14 (penjualan dicatat), dan
/// 8.16 (tersimpan di HP).
///
/// Susunan siap: kartu ringkasan bulan, saringan Semua/Belum lunas/Lunas, lalu
/// `Grup daftar`. Tombol di bawah selalu "Catat penjualan"; ia membuka form
/// 8.7. Ikon grafik di AppBar membuka ringkasan 8.5.
class V2PenjualanListPage extends StatefulWidget {
  const V2PenjualanListPage({
    super.key,
    this.initialPenjualan,
    this.ringkasan = designRingkasanPenjualan,
    this.state = V2PenjualanListState.ready,
    this.filterIndex = 0,
    this.toast,
  });

  /// Frame `8.2 Memuat penjualan`.
  V2PenjualanListPage.loading({super.key})
    : initialPenjualan = designPenjualan,
      ringkasan = designRingkasanPenjualan,
      state = V2PenjualanListState.loading,
      filterIndex = 0,
      toast = null;

  /// Frame `8.3 Gagal memuat penjualan`.
  V2PenjualanListPage.error({super.key})
    : initialPenjualan = designPenjualan,
      ringkasan = designRingkasanPenjualan,
      state = V2PenjualanListState.error,
      filterIndex = 0,
      toast = null;

  /// Frame `8.4 Belum ada penjualan`.
  const V2PenjualanListPage.empty({super.key})
    : initialPenjualan = const <V2Penjualan>[],
      ringkasan = designRingkasanPenjualan,
      state = V2PenjualanListState.empty,
      filterIndex = 0,
      toast = null;

  /// Frame `8.6 Penjualan, belum lunas`: saringan "Belum lunas" menyala.
  V2PenjualanListPage.belumLunas({super.key})
    : initialPenjualan = designPenjualan,
      ringkasan = designRingkasanPenjualan,
      state = V2PenjualanListState.ready,
      filterIndex = 1,
      toast = null;

  /// Frame `8.14 Penjualan dicatat`.
  V2PenjualanListPage.created({super.key})
    : initialPenjualan = designPenjualanBaru,
      ringkasan = designRingkasanPenjualanBaru,
      state = V2PenjualanListState.created,
      filterIndex = 0,
      toast = 'Penjualan dicatat';

  /// Frame `8.16 Tersimpan di HP`.
  V2PenjualanListPage.offline({super.key})
    : initialPenjualan = designPenjualanOffline,
      ringkasan = designRingkasanPenjualan,
      state = V2PenjualanListState.offline,
      filterIndex = 0,
      toast = 'Tersimpan di HP';

  final List<V2Penjualan>? initialPenjualan;
  final V2PenjualanRingkasan ringkasan;
  final V2PenjualanListState state;
  final int filterIndex;

  /// Toast yang sudah tampil saat halaman dibuka (frame 8.14/8.16).
  final String? toast;

  static Route<void> route({
    List<V2Penjualan>? initialPenjualan,
    V2PenjualanRingkasan ringkasan = designRingkasanPenjualan,
    String? toast,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => V2PenjualanListPage(
        initialPenjualan: initialPenjualan,
        ringkasan: ringkasan,
        toast: toast,
      ),
    );
  }

  @override
  State<V2PenjualanListPage> createState() => _V2PenjualanListPageState();
}

class _V2PenjualanListPageState extends State<V2PenjualanListPage> {
  static const List<String> _filters = <String>['Semua', 'Belum lunas', 'Lunas'];

  late List<V2Penjualan> _items = widget.initialPenjualan ?? designPenjualan;
  late int _filter = widget.filterIndex;
  Timer? _toastTimer;
  String? _toast;

  bool get _loading => widget.state == V2PenjualanListState.loading;
  bool get _error => widget.state == V2PenjualanListState.error;
  bool get _emptyList => widget.state == V2PenjualanListState.empty;
  bool get _offline => widget.state == V2PenjualanListState.offline;

  /// Ikon grafik hanya muncul saat daftar siap dibaca (frame 8.1/8.6/8.14/
  /// 8.16); di keadaan memuat, gagal, dan kosong slotnya dibiarkan kosong.
  bool get _showSummaryAction => !_loading && !_error && !_emptyList;

  List<V2Penjualan> get _filtered => switch (_filter) {
    1 => _items.where((item) => !item.lunas).toList(),
    2 => _items.where((item) => item.lunas).toList(),
    _ => _items,
  };

  @override
  void initState() {
    super.initState();
    _toast = widget.toast;
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

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() => _toast = message);
    _scheduleToastDismiss();
  }

  Future<void> _openSummary() async {
    await Navigator.of(context).push(V2PenjualanSummaryPage.route());
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<V2Penjualan>(
      V2PenjualanFormPage.route(),
    );
    if (created == null || !mounted) return;
    _items = [created, ..._items];
    _filter = 0;
    _showToast('Penjualan dicatat');
  }

  Future<void> _openDetail(V2Penjualan penjualan) async {
    final updated = await Navigator.of(context).push<V2Penjualan>(
      V2PenjualanDetailPage.route(penjualan),
    );
    if (updated == null || !mounted) return;
    setState(() {
      _items = [
        for (final item in _items)
          if (item.id == updated.id) updated else item,
      ];
    });
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
                title: 'Penjualan',
                onBack: () => Navigator.of(context).maybePop(),
                trailing: _showSummaryAction
                    ? V2IconButton(
                        icon: V2IconName.chart,
                        semanticLabel: 'Ringkasan',
                        onPressed: _openSummary,
                      )
                    : null,
              ),
              Expanded(child: _buildBody()),
              if (!_loading && !_error) _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: _scrollPadding,
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 100),
            SizedBox(height: V2Space.lg),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: V2Space.xl),
              child: V2PenjualanSkeleton(),
            ),
          ],
        ),
      );
    }

    if (_error) {
      return SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: _scrollPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 100),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
              child: V2ErrorState(
                title: 'Gagal memuat',
                body: 'Periksa internet, lalu coba lagi.',
                actionLabel: 'Coba lagi',
                illustration: Image.asset(
                  V2PenjualanAssets.offlineNoInternet,
                  width: 160,
                  height: 160,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_emptyList) {
      return SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: _scrollPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 100),
            const SizedBox(height: 80),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
              child: V2ErrorState(
                title: 'Belum ada penjualan',
                body: 'Catat penjualan pertama.',
                illustration: Image.asset(
                  V2PenjualanAssets.salesProduce,
                  width: 160,
                  height: 160,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final rows = _filtered;
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: _scrollPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_offline) ...[
                  const V2Banner(message: 'Offline. Data tersimpan di HP.'),
                  const SizedBox(height: V2Space.lg),
                ],
                _buildSummary(),
              ],
            ),
          ),
          const SizedBox(height: V2Space.lg),
          _buildChips(),
          const SizedBox(height: V2Space.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
            child: V2GroupList(
              children: [
                for (final penjualan in rows)
                  V2PenjualanRow(
                    penjualan: penjualan,
                    onTap: () => _openDetail(penjualan),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  EdgeInsets get _scrollPadding => const EdgeInsets.only(
    top: V2Space.sm,
    bottom: V2Space.xl,
  );

  Widget _buildSummary() {
    return V2SummaryCard(
      kicker: widget.ringkasan.kicker,
      value: widget.ringkasan.total,
      meta: widget.ringkasan.kgTerjual,
      extra: widget.ringkasan.belumLunas,
      badge: widget.ringkasan.adaBelumLunas
          ? const V2Badge(label: 'Belum lunas', status: V2BadgeStatus.warning)
          : null,
    );
  }

  Widget _buildChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
      child: Row(
        children: [
          for (var index = 0; index < _filters.length; index++) ...[
            if (index > 0) const SizedBox(width: V2Space.sm),
            V2Chip(
              label: _filters[index],
              selected: index == _filter,
              onTap: () => setState(() => _filter = index),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return V2ActionBar(
      toast: _toast,
      toastTone: _offline ? V2ToastTone.info : V2ToastTone.success,
      actions: [V2Button(label: 'Catat penjualan', onPressed: _openCreate)],
    );
  }
}
