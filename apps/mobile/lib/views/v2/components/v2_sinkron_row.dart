import 'package:flutter/material.dart';

import '../widgets/v2_badge.dart';
import '../widgets/v2_icon.dart';
import '../widgets/v2_stock_item.dart';
import 'v2_sinkron_data.dart';

/// Baris antrean sinkron di dalam `Grup daftar` (frame 11.4, 11.5, 11.7).
///
/// Bentuknya sama dengan baris penjualan: lead 40 berikon jenis data, judul
/// nama jenis, subjudul keterangan, lalu kode data dengan badge di kanannya.
/// Hanya baris "Rusak" memakai lead kuning karena perlu perhatian.
class V2SinkronRow extends StatelessWidget {
  const V2SinkronRow({super.key, required this.item, this.onTap});

  final V2SinkronItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return V2StockItem(
      withCard: false,
      iconSize: 24,
      icon: switch (item.jenis) {
        V2SinkronJenis.semaian || V2SinkronJenis.panen => V2IconName.sprout,
        V2SinkronJenis.stok => V2IconName.box,
        V2SinkronJenis.penjualan => V2IconName.chart,
        V2SinkronJenis.rusak => V2IconName.warning,
      },
      tone: item.jenis == V2SinkronJenis.rusak
          ? V2StockItemTone.warning
          : V2StockItemTone.blue,
      title: item.title,
      subtitle: item.subtitle,
      quantity: item.kode,
      badge: _badge(),
      onTap: onTap,
    );
  }

  Widget _badge() => switch (item.status) {
    V2SinkronStatus.terkirim => const V2Badge(
      label: 'Terkirim',
      status: V2BadgeStatus.success,
    ),
    V2SinkronStatus.antrean => const V2Badge(
      label: 'Antrean',
      status: V2BadgeStatus.pending,
    ),
    V2SinkronStatus.gagal => const V2Badge(
      label: 'Gagal',
      status: V2BadgeStatus.error,
    ),
  };
}
