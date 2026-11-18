import 'package:flutter/material.dart';

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

/// Detail satu semaian (frame 5.14–5.16, 5.19, 5.23, 5.29, 5.30).
///
/// Susunannya: banner "Siap pindah ke meja" saat semaian genap HSS 15 dan belum
/// dipindah sama sekali, kartu ringkasan biru, lalu kartu "Tahap" berisi tiga
/// langkah linimasa (Semai, Siap pindah, Tumbuh di meja).
///
/// Tombol bawah mengikuti keadaan: semaian berjalan hanya "Ubah", siap pindah
/// menambah "Pindah ke meja", sedangkan semaian selesai tidak punya footer
/// karena tidak bisa diubah lagi.
class V2SemaianDetailPage extends StatelessWidget {
  const V2SemaianDetailPage({
    super.key,
    required this.item,
    this.onEdit,
    this.onMove,
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

  final V2SemaianItem item;
  final VoidCallback? onEdit;
  final VoidCallback? onMove;

  static Route<V2SemaianItem> route(V2SemaianItem item) {
    return MaterialPageRoute<V2SemaianItem>(
      builder: (_) => V2SemaianDetailPage(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final siap = item.status == V2SemaianStatus.siapPindah;

    return Theme(
      data: V2Theme.light,
      child: Scaffold(
        backgroundColor: V2Colors.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              V2AppBar(
                title: 'Detail semaian',
                onBack: () => Navigator.of(context).maybePop(),
              ),
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
                    ],
                  ),
                ),
              ),
              if (!item.selesai) _actions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ringkasan() {
    return V2SummaryCard(
      kicker: item.labelSemai,
      value: item.labelHss,
      meta: item.labelBenih,
      extra: item.labelPindah ?? item.labelStokTerpakai,
      badge: _badge(),
    );
  }

  /// Lencana status di dalam kartu ringkasan (bukan `V2Badge` biasa: status
  /// Selesai memakai latar hijau muda dengan teks abu, frame 5.19/5.29/5.30).
  Widget _badge() {
    final (String label, Color background, Color foreground, V2IconName icon) =
        switch (item.status) {
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
      height: 28,
      padding: const EdgeInsets.only(
        left: V2Space.sm,
        right: V2Space.lg,
        top: V2Space.xs,
        bottom: V2Space.xs,
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
          Text(label, style: V2Type.label.copyWith(color: foreground)),
        ],
      ),
    );
  }

  Widget _tahap() {
    final selesai = item.selesai;
    final siap = item.siapPindah;
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
                : 'HSS 15. ${item.hariMenujuSiap} hari lagi',
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
                ? '${item.pindahKe ?? 'Meja'}. Berjalan'
                : 'HSS 15 sampai 60',
            state: selesai ? V2TimelineState.active : V2TimelineState.pending,
          ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context) {
    final siap = item.status == V2SemaianStatus.siapPindah;
    return V2ActionBar(
      actions: [
        if (siap)
          V2Button(
            label: 'Pindah ke meja',
            onPressed: onMove ?? () => _pindah(context),
          ),
        V2Button(
          label: 'Ubah',
          type: V2ButtonType.tertiary,
          onPressed: onEdit ?? () => _notice(context, 'Ubah semaian (5.25)'),
        ),
      ],
    );
  }

  /// Buka form 5.17, lalu terapkan hasilnya ke semaian ini dan kembali ke
  /// daftar dengan baris yang sudah diperbarui.
  Future<void> _pindah(BuildContext context) async {
    final result = await Navigator.of(context).push<V2SemaianPindah>(
      MaterialPageRoute<V2SemaianPindah>(
        builder: (_) => V2PindahMejaFormPage(item: item),
      ),
    );
    if (result == null || !context.mounted) return;

    final sisa = (item.sisaBenih ?? item.jumlahBenih) - result.jumlah;
    final updated = item.copyWith(
      sisaBenih: sisa > 0 ? sisa : null,
      hapusSisaBenih: sisa <= 0,
      jumlahPindah: (item.jumlahPindah ?? 0) + result.jumlah,
      pindahKe: result.meja,
      selesai: sisa <= 0,
    );
    Navigator.of(context).pop(updated);
  }

  void _notice(BuildContext context, String alur) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$alur belum tersedia.')));
  }
}