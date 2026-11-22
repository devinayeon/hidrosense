import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import '../widgets/v2_badge.dart';
import '../widgets/v2_icon.dart';
import '../widgets/v2_stock_item.dart';
import 'v2_inventaris_data.dart';

/// Baris stok di dalam `Grup daftar` (frame 4.1, 4.8, 4.9, 4.28).
///
/// Semua baris dipaku 80 tinggi seperti komponen `StockItem`: lead 40 berikon
/// jenis, judul nama barang, subjudul jenis, lalu jumlah di kanan dengan badge
/// keadaan (`Menipis`/`Habis`). Baris tanpa badge mengisi 72 alami, jadi
/// `SizedBox(height: 80)` dipakai supaya tinggi semua baris sama.
///
/// Barang arsip (frame 4.28) memakai nada `#4B5563` untuk ikon dan tulisan
/// dengan lead tetap biru muda, tanpa badge; bentuk itu digambar di sini
/// mengikuti baris akun `Nonaktif`, bukan lewat `V2StockItem` yang selalu
/// memakai tinta pekat.
class V2InventarisRow extends StatelessWidget {
  const V2InventarisRow({super.key, required this.item, this.onTap});

  final V2InventarisItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 80),
      child: item.arsip ? _archived() : _active(),
    );
  }

  Widget _active() {
    return V2StockItem(
      withCard: false,
      iconSize: 24,
      icon: _icon,
      title: item.nama,
      subtitle: item.jenis.label,
      quantity: item.kuantitas,
      badge: _badge,
      onTap: onTap,
    );
  }

  /// Baris arsip: lead biru muda, tetapi ikon, judul, subjudul, dan jumlah
  /// memakai `#4B5563` (frame 4.28).
  Widget _archived() {
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: V2Space.lg,
        vertical: V2Space.md,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: V2Colors.blue50,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: V2Icon(_icon, size: 24, color: V2Colors.slate600),
            ),
          ),
          const SizedBox(width: V2Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.nama,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: V2Type.bodyStrong.copyWith(color: V2Colors.slate600),
                ),
                const SizedBox(height: V2Space.xs),
                Text(
                  item.jenis.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: V2Type.label.copyWith(color: V2Colors.slate600),
                ),
              ],
            ),
          ),
          const SizedBox(width: V2Space.md),
          Text(
            item.kuantitas,
            style: V2Type.bodyStrong.copyWith(color: V2Colors.slate600),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: content),
    );
  }

  V2IconName get _icon => switch (item.jenis) {
    V2JenisBarang.benih => V2IconName.sprout,
    V2JenisBarang.nutrisi => V2IconName.droplet,
    V2JenisBarang.media => V2IconName.layers,
    V2JenisBarang.obat => V2IconName.care,
  };

  /// Aman tidak berlencana; menipis diberi peringatan kuning, habis merah.
  /// Barang yang menunggu sinkron memakai lencana "Antrean" (frame 4.16), dan
  /// barang arsip tidak berlencana sama sekali (frame 4.28).
  Widget? get _badge {
    if (item.arsip) return null;
    if (item.antrean) {
      return const V2Badge(label: 'Antrean', status: V2BadgeStatus.pending);
    }
    return switch (item.status) {
      V2InventarisStatus.menipis => const V2Badge(
        label: 'Menipis',
        status: V2BadgeStatus.warning,
      ),
      V2InventarisStatus.habis => const V2Badge(
        label: 'Habis',
        status: V2BadgeStatus.error,
      ),
      V2InventarisStatus.aman => null,
    };
  }
}
