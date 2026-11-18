import 'package:flutter/material.dart';

import '../components/v2_inventaris_data.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_action_bar.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_badge.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_summary_card.dart';

/// Detail satu barang stok (frame 4.17–4.20, 4.29).
///
/// Susunannya sama untuk semua keadaan: kartu ringkasan biru (nama + jenis,
/// jumlah, stok minimum, badge keadaan), kartu putih "Riwayat", lalu baris aksi
/// "Ubah"/"Arsipkan". Footer "Catat stok" melayang di bawah; barang habis
/// memakai label "Catat stok masuk" dan barang arsip tidak punya baris aksi
/// maupun footer (frame 4.29).
class V2InventarisDetailPage extends StatelessWidget {
  const V2InventarisDetailPage({
    super.key,
    required this.item,
    this.footerLabel,
    this.showAksi = true,
    this.onCatatStok,
    this.onUbah,
    this.onArsipkan,
  });

  /// Frame `4.17 Detail barang baru`: Benih Lollo Rossa baru masuk.
  const V2InventarisDetailPage.baru({Key? key})
    : this(key: key, item: designDetailBaru, footerLabel: 'Catat stok');

  /// Frame `4.18 Detail barang menipis`: Benih Butterhead sisa 2 pak.
  const V2InventarisDetailPage.menipis({Key? key})
    : this(key: key, item: designDetailMenipis, footerLabel: 'Catat stok');

  /// Frame `4.19 Detail barang`: Benih Romaine stoknya cukup.
  const V2InventarisDetailPage.biasa({Key? key})
    : this(key: key, item: designDetailBiasa, footerLabel: 'Catat stok');

  /// Frame `4.20 Detail barang habis`: Rockwool ludes.
  const V2InventarisDetailPage.habis({Key? key})
    : this(key: key, item: designDetailHabis, footerLabel: 'Catat stok masuk');

  /// Frame `4.29 Detail barang arsip`: Benih Romaine sudah diarsipkan.
  const V2InventarisDetailPage.arsip({Key? key})
    : this(
        key: key,
        item: designDetailArsip,
        footerLabel: null,
        showAksi: false,
      );

  final V2InventarisItem item;

  /// Label tombol footer; null berarti tanpa footer (frame 4.29).
  final String? footerLabel;

  /// Baris "Ubah"/"Arsipkan"; false pada frame 4.29.
  final bool showAksi;

  /// Ketukan pada tombol aksi; null berarti hanya pratinjau (belum tersambung).
  final VoidCallback? onCatatStok;
  final VoidCallback? onUbah;
  final VoidCallback? onArsipkan;

  /// Label footer untuk satu barang: arsip tanpa footer, barang habis
  /// "Catat stok masuk", sisanya "Catat stok".
  static String? footerLabelFor(V2InventarisItem item) => item.arsip
      ? null
      : item.status == V2InventarisStatus.habis
      ? 'Catat stok masuk'
      : 'Catat stok';

  static Route<V2InventarisItem> route(
    V2InventarisItem item, {
    VoidCallback? onCatatStok,
    VoidCallback? onUbah,
    VoidCallback? onArsipkan,
  }) {
    return MaterialPageRoute<V2InventarisItem>(
      builder: (_) => V2InventarisDetailPage(
        item: item,
        footerLabel: footerLabelFor(item),
        showAksi: !item.arsip,
        onCatatStok: onCatatStok,
        onUbah: onUbah,
        onArsipkan: onArsipkan,
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
              V2AppBar(
                title: 'Detail barang',
                onBack: () => Navigator.of(context).pop(item),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    V2Space.xl,
                    V2Space.sm,
                    V2Space.xl,
                    V2Space.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      V2SummaryCard(
                        kicker:
                            '${item.nama}, ${item.jenis.label.toLowerCase()}',
                        value: item.kuantitas,
                        meta: item.minimumLabel,
                        badge: _badge(),
                      ),
                      const SizedBox(height: V2Space.lg),
                      _riwayat(),
                      if (showAksi) ...[
                        const SizedBox(height: V2Space.lg),
                        Row(
                          children: [
                            Expanded(
                              child: V2Button(
                                label: 'Ubah',
                                type: V2ButtonType.tertiary,
                                onPressed: onUbah ?? () {},
                              ),
                            ),
                            const SizedBox(width: V2Space.lg),
                            Expanded(
                              child: V2Button(
                                label: 'Arsipkan',
                                type: V2ButtonType.destructive,
                                onPressed: onArsipkan ?? () {},
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (footerLabel != null)
                V2ActionBar(
                  actions: [
                    V2Button(
                      label: footerLabel!,
                      onPressed: onCatatStok ?? () {},
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Kartu putih "Riwayat": judul, lalu satu baris per keluar-masukan.
  Widget _riwayat() {
    return Container(
      padding: const EdgeInsets.all(V2Space.xl),
      decoration: BoxDecoration(
        color: V2Colors.white,
        borderRadius: BorderRadius.circular(V2Radius.card),
        boxShadow: V2Shadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Riwayat', style: V2Type.h2),
          for (final baris in item.riwayat) ...[
            const SizedBox(height: V2Space.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(baris.label, style: V2Type.body)),
                Text(
                  baris.tanggal,
                  style: V2Type.label.copyWith(color: V2Colors.muted),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Keadaan stok: arsip memakai badge netral "Arsip"; sisanya mengikuti
  /// kecukupan stok (frame 4.17–4.20).
  Widget _badge() {
    if (item.arsip) {
      return const V2Badge(label: 'Arsip', status: V2BadgeStatus.neutral);
    }
    return switch (item.status) {
      V2InventarisStatus.aman => const V2Badge(
        label: 'Cukup',
        status: V2BadgeStatus.success,
      ),
      V2InventarisStatus.menipis => const V2Badge(
        label: 'Menipis',
        status: V2BadgeStatus.warning,
      ),
      V2InventarisStatus.habis => const V2Badge(
        label: 'Habis',
        status: V2BadgeStatus.error,
      ),
    };
  }
}
