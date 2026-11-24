import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import '../widgets/v2_bento_tile.dart';
import '../widgets/v2_icon.dart';

/// Dua petak statistik beranda (frame 2.1/2.2/2.5/2.6).
///
/// Kiri: stok menipis (tone Warning, ikon kotak). Kanan: lubang terisi
/// (tone Default, ikon semai).
class V2BerandaStats extends StatelessWidget {
  const V2BerandaStats({
    super.key,
    this.lowStock = '2',
    this.filledHoles = '400',
    this.onLowStock,
    this.onFilledHoles,
  });

  final String lowStock;
  final String filledHoles;
  final VoidCallback? onLowStock;
  final VoidCallback? onFilledHoles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = (constraints.maxWidth - V2Space.lg) / 2;
        // `IntrinsicHeight` + `stretch` menyamakan tinggi kedua petak walau
        // salah satu teksnya membungkus lebih banyak baris (BUG-20).
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              V2BentoTile(
                value: lowStock,
                label: 'Stok menipis',
                icon: V2IconName.box,
                tone: V2BentoTone.warning,
                size: size,
                onTap: onLowStock,
              ),
              const SizedBox(width: V2Space.lg),
              V2BentoTile(
                value: filledHoles,
                label: 'Lubang terisi',
                icon: V2IconName.sprout,
                size: size,
                onTap: onFilledHoles,
              ),
            ],
          ),
        );
      },
    );
  }
}
