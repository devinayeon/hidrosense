import 'package:flutter/material.dart';

import '../widgets/v2_badge.dart';
import '../widgets/v2_icon.dart';
import '../widgets/v2_stock_item.dart';
import 'v2_inventaris_data.dart';

/// Baris stok di dalam `Grup daftar` (frame 4.1, 4.8, 4.9).
///
/// Semua baris dipaku 80 tinggi seperti komponen `StockItem`: lead 40 berikon
/// jenis, judul nama barang, subjudul jenis, lalu jumlah di kanan dengan badge
/// keadaan (`Menipis`/`Habis`). Baris tanpa badge mengisi 72 alami, jadi
/// `SizedBox(height: 80)` dipakai supaya tinggi semua baris sama.
class V2InventarisRow extends StatelessWidget {
  const V2InventarisRow({super.key, required this.item, this.onTap});

  final V2InventarisItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: V2StockItem(
        withCard: false,
        iconSize: 24,
        icon: _icon,
        title: item.nama,
        subtitle: item.jenis.label,
        quantity: item.kuantitas,
        badge: _badge,
        onTap: onTap,
      ),
    );
  }

  V2IconName get _icon => switch (item.jenis) {
    V2JenisBarang.benih => V2IconName.sprout,
    V2JenisBarang.nutrisi => V2IconName.droplet,
    V2JenisBarang.media => V2IconName.layers,
    V2JenisBarang.obat => V2IconName.care,
  };

  /// Aman tidak berlencana; menipis diberi peringatan kuning, habis merah.
  /// Barang yang menunggu sinkron memakai lencana "Antrean" (frame 4.16).
  Widget? get _badge {
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
