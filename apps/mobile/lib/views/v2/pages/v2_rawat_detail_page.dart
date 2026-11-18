import 'package:flutter/material.dart';

import '../components/v2_rawat_assets.dart';
import '../components/v2_rawat_data.dart';
import '../components/v2_rawat_foto_card.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_action_bar.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_badge.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_summary_card.dart';
import 'v2_rawat_foto_page.dart';

/// Detail satu catatan perawatan (frame 9.24, 9.26, 9.27).
///
/// Foto contoh 160 di puncak, lalu kartu ringkasan biru berisi meja + tanggal,
/// status, nama hama, obat yang dipakai, dan catatan AI. Hanya bisa dibaca;
/// satu-satunya aksi adalah “Foto ulang untuk cek”.
class V2RawatDetailPage extends StatelessWidget {
  const V2RawatDetailPage({super.key, required this.item});

  /// Frame `9.24 Detail perawatan baru`: 15 Nov, Obat Nabati.
  V2RawatDetailPage.baru({Key? key})
    : this(key: key, item: designRawatBaru);

  /// Frame `9.26 Detail perawatan, antrean`: belum tersimpan di server.
  V2RawatDetailPage.antrean({Key? key})
    : this(key: key, item: designRawatAntrean);

  /// Frame `9.27 Detail perawatan (12 Nov)`: Sabun insektisida.
  V2RawatDetailPage.lama({Key? key})
    : this(key: key, item: designRawatSelesai12);

  final V2RawatItem item;

  static Route<void> route(V2RawatItem item) {
    return MaterialPageRoute<void>(
      builder: (_) => V2RawatDetailPage(item: item),
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
              V2AppBar(
                title: 'Detail perawatan',
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
                      const V2RawatFotoCard(height: 160),
                      const SizedBox(height: V2Space.lg),
                      V2SummaryCard(
                        kicker: item.labelKicker,
                        badge: item.antrean
                            ? const V2Badge(
                                label: 'Antrean',
                                status: V2BadgeStatus.pending,
                              )
                            : const V2Badge(
                                label: 'Selesai',
                                status: V2BadgeStatus.success,
                              ),
                        value: item.hama,
                        meta: item.labelObat,
                        extra: item.labelExtra,
                      ),
                    ],
                  ),
                ),
              ),
              V2ActionBar(
                actions: [
                  V2Button(
                    label: 'Foto ulang untuk cek',
                    type: V2ButtonType.tertiary,
                    onPressed: () => Navigator.of(
                      context,
                    ).push(V2RawatFotoPage.route()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Halaman “Perawatan dicatat” (frame 9.23).
///
/// Tanpa AppBar: ilustrasi 160 di tengah atas, judul, lalu ajakan cek tiga hari
/// lagi. Footer 162 berisi “Selesai” dan “Lihat riwayat” (ghost).
class V2RawatSavedPage extends StatelessWidget {
  const V2RawatSavedPage({super.key});

  /// Frame `9.23 Perawatan dicatat`.
  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const V2RawatSavedPage());
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
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.only(top: 72),
                  child: Column(
                    children: [
                      const SizedBox(height: 154),
                      Image.asset(
                        V2RawatAssets.harvestLettuce,
                        width: 160,
                        height: 160,
                      ),
                      const SizedBox(height: V2Space.lg),
                      Text('Perawatan dicatat', style: V2Type.h1),
                      const SizedBox(height: V2Space.lg),
                      Text(
                        'Cek lagi dalam 3 hari.',
                        textAlign: TextAlign.center,
                        style: V2Type.body.copyWith(color: V2Colors.muted),
                      ),
                    ],
                  ),
                ),
              ),
              _footer(context),
            ],
          ),
        ),
      ),
    );
  }

  /// Footer 162: primary 56, jarak 16, ghost 48, sisa 8 di atas home
  /// indicator. Disusun sendiri karena `V2ActionBar` memasang dua tombol 56.
  Widget _footer(BuildContext context) {
    return Container(
      color: V2Colors.canvas,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            V2Space.xl,
            0,
            V2Space.xl,
            V2Space.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              V2Button(
                label: 'Selesai',
                onPressed: () => Navigator.of(context).popUntil(
                  (route) =>
                      route.settings.name == 'v2-rawat-list' ||
                      route.isFirst,
                ),
              ),
              const SizedBox(height: V2Space.lg),
              V2Button(
                label: 'Lihat riwayat',
                type: V2ButtonType.ghost,
                onPressed: () => Navigator.of(context).push(
                  V2RawatDetailPage.route(designRawatBaru),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}