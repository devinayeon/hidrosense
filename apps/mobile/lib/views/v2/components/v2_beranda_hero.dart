import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import '../widgets/v2_cycle_ring.dart';

/// Kartu hero biru di beranda (frame 2.1/2.2/2.5/2.6).
///
/// Susunan: teks siklus di kiri (kicker 14/20, judul 28/36, jarak 37 hari) dan
/// cincin siklus ringkas di kanan. Menekan kartu membuka detail siklus (2.7).
class V2BerandaHero extends StatelessWidget {
  const V2BerandaHero({
    super.key,
    this.kicker = 'Siklus berjalan',
    this.title = 'Meja A2',
    this.subtitle = '37 hari lagi',
    this.value = 23,
    this.total = 60,
    this.windowEnd = 15,
    this.onTap,
  });

  final String kicker;
  final String title;
  final String subtitle;
  final int value;
  final int total;
  final int windowEnd;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // 160 adalah tinggi minimum; huruf besar membuat kartu tumbuh.
    final content = Container(
      // Tinggi minimum (bukan tetap): teks boleh membungkus dan kartu ikut
      // tumbuh saat skala teks sistem besar (BUG-20).
      constraints: const BoxConstraints(minHeight: 160),
      padding: const EdgeInsets.all(V2Space.xl),
      decoration: BoxDecoration(
        color: V2Colors.blue500,
        borderRadius: BorderRadius.circular(V2Radius.sheet),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  kicker,
                  style: V2Type.label.copyWith(color: V2Colors.white),
                ),
                const SizedBox(height: V2Space.xs),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: V2Type.h1.copyWith(color: V2Colors.white),
                ),
                const SizedBox(height: V2Space.xs),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: V2Type.body.copyWith(color: V2Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(width: V2Space.lg),
          V2CycleRing(
            value: value,
            total: total,
            windowEnd: windowEnd,
            trackColor: V2Colors.white.withValues(alpha: 0.22),
            windowColor: V2Colors.white.withValues(alpha: 0.30),
            progressColor: V2Colors.lime400,
            contentColor: V2Colors.white,
            unitColor: V2Colors.white,
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(V2Radius.sheet),
        child: content,
      ),
    );
  }
}
