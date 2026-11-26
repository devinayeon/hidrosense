import 'dart:async';

import 'package:flutter/material.dart';

import '../components/v2_penjualan_info_card.dart';
import '../components/v2_semaian_data.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_action_bar.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_banner.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_icon.dart';
import '../widgets/v2_summary_card.dart';
import '../widgets/v2_timeline_step.dart';
import 'v2_pindah_meja_page.dart';
import 'v2_semaian_edit_page.dart';

/// Detail satu semaian (frame 5.14–5.16, 5.19, 5.23, 5.29, 5.30).
///
/// Susunannya: banner "Siap pindah ke meja" saat semaian genap HSS 15 dan belum
/// dipindah sama sekali, kartu ringkasan biru, lalu kartu "Tahap" berisi tiga
/// langkah linimasa (Semai, Siap pindah, Tumbuh di meja).
///
/// Tombol bawah mengikuti keadaan: semaian berjalan hanya "Ubah", siap pindah
/// menambah "Pindah ke meja", sedangkan semaian selesai tidak punya footer
/// karena tidak bisa diubah lagi.
class V2SemaianDetailPage extends StatefulWidget {
  const V2SemaianDetailPage({
    super.key,
    required this.item,
    this.onEdit,
    this.onMove,
    this.toast,
    this.openEditOnStart = false,
  });

  /// Frame `5.14 Detail semaian baru`: Romaine baru disemai, HSS 0.
  V2SemaianDetailPage.baru({Key? key})
    : this(key: key, item: designSemaianBaru);

  /// Frame `5.15 Detail semaian`: Butterhead berjalan, HSS 10.
  V2SemaianDetailPage.biasa({Key? key})
    : this(key: key, item: designSemaianButterhead);

  /// Frame `5.16 Detail siap pindah`: Romaine HSS 17, semua benih masih ada.
  V2SemaianDetailPage.siapPindah({Key? key})
    : this(key: key, item: designSemaianRomaineSiapPindah);

  /// Frame `5.23 Detail siap pindah, ada sisa`: 120 sudah pindah, sisa 80.
  V2SemaianDetailPage.sisa({Key? key})
    : this(key: key, item: designSemaianSisa);

  /// Frame `5.30 Detail semaian selesai`: 42 benih pindah ke Meja A2.
  V2SemaianDetailPage.selesai({Key? key})
    : this(key: key, item: designSemaianSelesai);

  /// Frame `5.19 Detail selesai, dipindah semua`: 200 benih pindah ke Meja A2.
  V2SemaianDetailPage.dipindahSemua({Key? key})
    : this(key: key, item: designSemaianDipindahSemua);

  /// Frame `5.29 Detail selesai, sisa tidak dipindah`: 120 pindah, 80 tinggal.
  V2SemaianDetailPage.selesaiSisa({Key? key})
    : this(key: key, item: designSemaianSelesaiSisa);

  /// Frame `5.26 Perubahan tersimpan`: Butterhead 140 benih dan toast di atas
  /// bilah aksi.
  V2SemaianDetailPage.tersimpan({Key? key})
    : this(
        key: key,
        item: designSemaianTersimpan,
        toast: 'Perubahan tersimpan',
      );

  /// Semaian yang ditampilkan; halaman memegang salinan supaya perubahan dari
  /// form ubah langsung terlihat sebelum kembali ke daftar.
  final V2SemaianItem item;
  final VoidCallback? onEdit;
  final VoidCallback? onMove;

  /// Toast yang sudah tampil saat halaman dibuka (frame 5.26).
  final String? toast;

  /// Membuka form "Ubah semaian" begitu halaman tampil (frame 5.25/5.27).
  final bool openEditOnStart;

  static Route<V2SemaianItem> route(V2SemaianItem item) {
    return MaterialPageRoute<V2SemaianItem>(
      builder: (_) => V2SemaianDetailPage(item: item),
    );
  }

  @override
  State<V2SemaianDetailPage> createState() => _V2SemaianDetailPageState();
}

class _V2SemaianDetailPageState extends State<V2SemaianDetailPage> {
  late V2SemaianItem _item = widget.item;
  String? _toast;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _toast = widget.toast;
    if (_toast != null) _scheduleToastDismiss();
    if (widget.openEditOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ubah();
      });
    }
  }

  @override
  void didUpdateWidget(covariant V2SemaianDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.item, oldWidget.item)) {
      _item = widget.item;
    }
    if (widget.toast != null && widget.toast != oldWidget.toast) {
      _toast = widget.toast;
      _scheduleToastDismiss();
    }
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

  void _close() => Navigator.of(context).pop(_item);

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final siap = item.status == V2SemaianStatus.siapPindah;

    return Theme(
      data: V2Theme.light,
      child: PopScope<V2SemaianItem>(
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
                V2AppBar(title: 'Detail semaian', onBack: _close),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      V2Space.xl,
                      V2Space.sm,
                      V2Space.xl,
                      V2Space.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (siap && item.sisaBenih == null) ...[
                          const V2Banner(
                            message: 'Siap pindah ke meja',
                            tone: V2BannerTone.success,
                          ),
                          const SizedBox(height: V2Space.lg),
                        ],
                        _ringkasan(),
                        const SizedBox(height: V2Space.lg),
                        _tahap(),
                        // Keterangan bebas yang diisi saat menambah semaian
                        // (keputusan SA): selalu ikut terbaca di detail.
                        if ((item.keterangan ?? '').isNotEmpty) ...[
                          const SizedBox(height: V2Space.lg),
                          V2PenjualanInfoCard(
                            rows: <V2PenjualanInfoRow>[
                              V2PenjualanInfoRow(
                                label: 'Keterangan',
                                value: item.keterangan!,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (!item.selesai) _actions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _ringkasan() {
    return V2SummaryCard(
      kicker: _item.labelSemai,
      value: _item.labelHss,
      meta: _item.labelBenih,
      extra: _item.labelPindah ?? _item.labelStokTerpakai,
      badge: _badge(),
    );
  }

  /// Lencana status di dalam kartu ringkasan (bukan `V2Badge` biasa: status
  /// Selesai memakai latar hijau muda dengan teks abu, frame 5.19/5.29/5.30).
  Widget _badge() {
    final (
      String label,
      Color background,
      Color foreground,
      V2IconName icon,
    ) = switch (_item.status) {
      V2SemaianStatus.berjalan => (
        'Berjalan',
        V2Colors.blue50,
        V2Colors.blue700,
        V2IconName.info,
      ),
      V2SemaianStatus.siapPindah => (
        'Siap pindah',
        V2Colors.green100,
        V2Colors.green700,
        V2IconName.check,
      ),
      V2SemaianStatus.selesai => (
        'Selesai',
        V2Colors.green100,
        V2Colors.slate600,
        V2IconName.minus,
      ),
    };

    return Container(
      padding: const EdgeInsets.only(
        left: V2Space.sm,
        right: V2Space.lg,
        top: V2Space.sm,
        bottom: V2Space.sm,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(V2Radius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          V2Icon(icon, size: V2Icons.small, color: foreground),
          const SizedBox(width: V2Space.xs),
          // Lencana di kartu ringkasan biru boleh membungkus; tinggi tetap 28
          // memotong label "Siap pindah" pada skala teks besar (BUG-24).
          Flexible(
            child: Text(
              label,
              style: V2Type.label.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tahap() {
    final selesai = _item.selesai;
    final siap = _item.siapPindah;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: V2Space.xl,
        vertical: V2Space.lg,
      ),
      decoration: BoxDecoration(
        color: V2Colors.white,
        borderRadius: BorderRadius.circular(V2Radius.card),
      ),
      child: Column(
        children: [
          V2TimelineStep(
            title: 'Semai',
            // Tahap semai selesai begitu HSS 15 tercapai, termasuk saat baru
            // siap pindah (frame 5.16/5.23).
            subtitle: selesai || siap
                ? 'HSS 0 sampai 15. Selesai'
                : 'HSS 0 sampai 15. Berjalan',
            state: selesai || siap
                ? V2TimelineState.done
                : V2TimelineState.active,
          ),
          const SizedBox(height: V2Space.sm),
          V2TimelineStep(
            title: 'Siap pindah',
            subtitle: selesai
                ? 'HSS 15. Selesai'
                : siap
                ? 'HSS 15. Sekarang'
                : 'HSS 15. ${_item.hariMenujuSiap} hari lagi',
            state: selesai
                ? V2TimelineState.done
                : siap
                ? V2TimelineState.active
                : V2TimelineState.pending,
          ),
          const SizedBox(height: V2Space.sm),
          V2TimelineStep(
            title: 'Tumbuh di meja',
            subtitle: selesai
                ? '${_item.pindahKe ?? 'Meja'}. Berjalan'
                : 'HSS 15 sampai 60',
            state: selesai ? V2TimelineState.active : V2TimelineState.pending,
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    final siap = _item.status == V2SemaianStatus.siapPindah;
    return V2ActionBar(
      toast: _toast,
      actions: [
        if (siap)
          V2Button(
            label: 'Pindah ke meja',
            onPressed: widget.onMove ?? _pindah,
          ),
        V2Button(
          label: 'Ubah',
          type: V2ButtonType.tertiary,
          onPressed: widget.onEdit ?? _ubah,
        ),
      ],
    );
  }

  /// Buka form "Ubah semaian" (5.25/5.27); hasilnya menggantikan semaian di
  /// halaman ini dan memunculkan toast "Perubahan tersimpan" (5.26).
  Future<void> _ubah() async {
    final updated = await Navigator.of(context).push<V2SemaianItem>(
      MaterialPageRoute<V2SemaianItem>(
        builder: (_) => V2SemaianEditPage(item: _item),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() => _item = updated);
    _showToast('Perubahan tersimpan');
  }

  /// Buka form 5.17, lalu terapkan hasilnya ke semaian ini dan kembali ke
  /// daftar dengan baris yang sudah diperbarui.
  Future<void> _pindah() async {
    final result = await Navigator.of(context).push<V2SemaianPindah>(
      MaterialPageRoute<V2SemaianPindah>(
        builder: (_) => V2PindahMejaFormPage(item: _item),
      ),
    );
    if (result == null || !mounted) return;

    final sisa = (_item.sisaBenih ?? _item.jumlahBenih) - result.jumlah;
    final updated = _item.copyWith(
      sisaBenih: sisa > 0 ? sisa : null,
      hapusSisaBenih: sisa <= 0,
      jumlahPindah: (_item.jumlahPindah ?? 0) + result.jumlah,
      pindahKe: result.meja,
      selesai: sisa <= 0,
    );
    Navigator.of(context).pop(updated);
  }
}
