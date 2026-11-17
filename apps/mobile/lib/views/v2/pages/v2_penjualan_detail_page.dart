import 'dart:async';

import 'package:flutter/material.dart';

import '../components/v2_penjualan_data.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_action_bar.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_badge.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_summary_card.dart';
import 'v2_penjualan_form_page.dart';

/// Detail satu penjualan: frame 8.15 (baru dicatat), 8.17 (masih antre),
/// 8.18 (belum lunas), 8.19 (lunas), 8.20 (ditandai lunas), dan 8.22
/// (perubahan tersimpan).
///
/// Status lunas bisa ditandai dari sini, kecuali selama penjualan masih di
/// antrean sinkron (frame 8.17) karena server belum mengenalnya.
class V2PenjualanDetailPage extends StatefulWidget {
  const V2PenjualanDetailPage({
    super.key,
    required this.penjualan,
    this.toast,
  });

  /// Frame `8.15 Detail penjualan baru`: Warung Sari belum lunas.
  V2PenjualanDetailPage.baru({super.key})
    : penjualan = penjualanWarungSari,
      toast = null;

  /// Frame `8.17 Detail penjualan, antrean`.
  V2PenjualanDetailPage.queued({super.key})
    : penjualan = penjualanWarungSariAntrean,
      toast = null;

  /// Frame `8.18 Detail penjualan`: Toko Segar belum lunas.
  V2PenjualanDetailPage.tokoSegar({super.key})
    : penjualan = penjualanTokoSegar,
      toast = null;

  /// Frame `8.19 Detail penjualan lunas`.
  V2PenjualanDetailPage.lunas({super.key})
    : penjualan = penjualanPasarInduk,
      toast = null;

  /// Frame `8.20 Ditandai lunas`: Toko Segar sudah lunas, toast menyala.
  V2PenjualanDetailPage.markedPaid({super.key})
    : penjualan = penjualanTokoSegar.copyWith(
        pembayaran: V2PenjualanBayar.lunas,
      ),
      toast = 'Ditandai lunas';

  /// Frame `8.22 Perubahan tersimpan`: harga Toko Segar naik jadi 41.000.
  V2PenjualanDetailPage.editSaved({super.key})
    : penjualan = penjualanTokoSegarDiubah,
      toast = 'Perubahan tersimpan';

  final V2Penjualan penjualan;

  /// Toast yang sudah tampil saat halaman dibuka (frame 8.20/8.22).
  final String? toast;

  static Route<V2Penjualan> route(V2Penjualan penjualan) {
    return MaterialPageRoute<V2Penjualan>(
      builder: (_) => V2PenjualanDetailPage(penjualan: penjualan),
    );
  }

  @override
  State<V2PenjualanDetailPage> createState() => _V2PenjualanDetailPageState();
}

class _V2PenjualanDetailPageState extends State<V2PenjualanDetailPage> {
  late V2Penjualan _penjualan = widget.penjualan;
  Timer? _toastTimer;
  String? _toast;

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

  void _close() => Navigator.of(context).pop(_penjualan);

  void _markPaid() {
    setState(() {
      _penjualan = _penjualan.copyWith(pembayaran: V2PenjualanBayar.lunas);
    });
    _showToast('Ditandai lunas');
  }

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<V2Penjualan>(
      V2PenjualanFormPage.route(initial: _penjualan),
    );
    if (updated == null || !mounted) return;
    setState(() => _penjualan = updated);
    _showToast('Perubahan tersimpan');
  }

  @override
  Widget build(BuildContext context) {
    final antrean = _penjualan.antrean;
    return Theme(
      data: V2Theme.light,
      child: PopScope<V2Penjualan>(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _close();
        },
        child: Scaffold(
          backgroundColor: V2Colors.canvas,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                V2AppBar(title: 'Detail penjualan', onBack: _close),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      V2Space.xl,
                      V2Space.sm,
                      V2Space.xl,
                      V2Space.lg,
                    ),
                    child: V2SummaryCard(
                      kicker: _penjualan.pembeli,
                      value: formatRupiahPenuh(_penjualan.total),
                      meta: formatMetaPenjualan(_penjualan),
                      extra: antrean ? 'Belum di server.' : _penjualan.panenAsal,
                      badge: _badge(),
                    ),
                  ),
                ),
                V2ActionBar(
                  toast: _toast,
                  note: antrean
                      ? 'Penjualan belum sinkron. Status bisa diubah setelah '
                            'sinkron.'
                      : null,
                  actions: [
                    if (!_penjualan.lunas)
                      V2Button(
                        label: 'Tandai lunas',
                        state: antrean
                            ? V2ButtonState.disabled
                            : V2ButtonState.normal,
                        onPressed: antrean ? null : _markPaid,
                      ),
                    V2Button(
                      label: 'Ubah',
                      type: V2ButtonType.tertiary,
                      onPressed: _edit,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge() {
    if (_penjualan.antrean) {
      return const V2Badge(label: 'Antrean', status: V2BadgeStatus.pending);
    }
    return _penjualan.lunas
        ? const V2Badge(label: 'Lunas', status: V2BadgeStatus.success)
        : const V2Badge(label: 'Belum lunas', status: V2BadgeStatus.warning);
  }
}
