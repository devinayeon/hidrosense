import 'package:flutter/material.dart';

import '../widgets/v2_badge.dart';
import '../widgets/v2_icon.dart';
import '../widgets/v2_stock_item.dart';
import 'v2_penjualan_data.dart';

/// Baris penjualan di dalam `Grup daftar` (frame 8.1, 8.6, 8.14, 8.16).
///
/// Lead 40 berikon `user`, judul nama pembeli, subjudul tanggal dan berat, lalu
/// nilai rupiah dengan badge di kanannya.
class V2PenjualanRow extends StatelessWidget {
  const V2PenjualanRow({super.key, required this.penjualan, this.onTap});

  final V2Penjualan penjualan;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return V2StockItem(
      withCard: false,
      iconSize: 24,
      icon: V2IconName.user,
      title: penjualan.pembeli,
      subtitle: formatSubJudulPenjualan(penjualan),
      quantity: formatRupiahJuta(penjualan.total),
      badge: _badge(),
      onTap: onTap,
    );
  }

  /// "Antrean" menang atas status pembayaran: selama belum terkirim, status
  /// lunas belum bisa dipercaya (frame 8.16 dan 8.17).
  Widget _badge() {
    if (penjualan.antrean) {
      return const V2Badge(label: 'Antrean', status: V2BadgeStatus.pending);
    }
    return penjualan.lunas
        ? const V2Badge(label: 'Lunas', status: V2BadgeStatus.success)
        : const V2Badge(label: 'Belum lunas', status: V2BadgeStatus.warning);
  }
}
