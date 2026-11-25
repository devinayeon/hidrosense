import 'package:flutter/material.dart';

import '../widgets/v2_badge.dart';
import '../widgets/v2_stock_item.dart';
import 'v2_meja_data.dart';

/// Baris meja di dalam `Grup daftar` (frame 6.1, 6.2, 6.8, 6.9).
///
/// Semua baris memakai tinggi minimum 80 seperti komponen `StockItem`: lead 40
/// berikon tunas, judul `Meja A2`, subjudul `Lubang terisi`, lalu rasio lubang di
/// kanan. Meja penuh menambah lencana kuning "Penuh"; meja yang lahir saat offline
/// memakai lencana biru "Antrean" (frame 6.9).
class V2MejaRow extends StatelessWidget {
  const V2MejaRow({super.key, required this.item, this.onTap});

  final V2MejaItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 80),
      child: V2StockItem(
        withCard: false,
        title: item.nama,
        subtitle: 'Lubang terisi',
        quantity: item.labelRasio,
        badge: item.antrean
            ? const V2Badge(label: 'Antrean', status: V2BadgeStatus.pending)
            : item.status == V2MejaStatus.penuh
            ? const V2Badge(label: 'Penuh', status: V2BadgeStatus.warning)
            : null,
        onTap: onTap,
      ),
    );
  }
}
