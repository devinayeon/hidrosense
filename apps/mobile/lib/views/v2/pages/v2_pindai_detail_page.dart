import 'package:flutter/material.dart';

import '../components/v2_pindai_badge.dart';
import '../components/v2_rawat_data.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_summary_card.dart';

/// Detail satu pindaian hama: meja, tanggal, keyakinan, dan status rekomendasi.
///
/// Layar ini sengaja ringkas. Tujuan utamanya memberi jalan dari daftar pindaian
/// di tab Rawat ke riwayat rotasi obat, tanpa membuka alur pindai lagi (BUG-22).
class V2PindaiDetailPage extends StatelessWidget {
  const V2PindaiDetailPage({super.key, required this.item, this.onOpenRotasi});

  final V2PindaiItem item;

  /// Membuka riwayat rotasi obat; null berarti tombolnya disembunyikan.
  final VoidCallback? onOpenRotasi;

  static Route<void> route(V2PindaiItem item, {VoidCallback? onOpenRotasi}) {
    return MaterialPageRoute<void>(
      builder: (_) => V2PindaiDetailPage(item: item, onOpenRotasi: onOpenRotasi),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = item.status;
    return Theme(
      data: V2Theme.light,
      child: Scaffold(
        backgroundColor: V2Colors.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              V2AppBar(
                title: 'Detail pindaian',
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    V2Space.xl,
                    V2Space.sm,
                    V2Space.xl,
                    V2Space.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      V2SummaryCard(
                        kicker: item.labelKicker,
                        badge: v2PindaiBadge(status),
                        value: item.hama,
                        meta: 'Keyakinan ${item.labelKeyakinan}',
                        extra: status == null
                            ? 'Belum ada rekomendasi obat untuk foto ini.'
                            : 'Rekomendasi obat: ${status.label}.',
                      ),
                      if (item.rincian.isNotEmpty) ...[
                        const SizedBox(height: V2Space.lg),
                        _RincianCard(rincian: item.rincian),
                      ],
                      if (onOpenRotasi != null) ...[
                        const SizedBox(height: V2Space.lg),
                        V2Button(
                          label: 'Lihat riwayat rotasi obat',
                          type: V2ButtonType.tertiary,
                          onPressed: onOpenRotasi,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartu putih berisi satu baris per hama yang terdeteksi pada foto.
class _RincianCard extends StatelessWidget {
  const _RincianCard({required this.rincian});

  final List<String> rincian;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(V2Space.xl),
      decoration: BoxDecoration(
        color: V2Colors.white,
        borderRadius: BorderRadius.circular(V2Radius.card),
        boxShadow: V2Shadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rincian deteksi', style: V2Type.h2),
          const SizedBox(height: V2Space.md),
          for (final baris in rincian)
            Padding(
              padding: const EdgeInsets.only(bottom: V2Space.sm),
              child: Text(baris, style: V2Type.body),
            ),
        ],
      ),
    );
  }
}