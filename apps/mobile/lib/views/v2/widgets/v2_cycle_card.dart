import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import 'v2_cycle_ring.dart';

/// Kartu siklus dari component `CycleCard`: cincin 112 + teks.
class V2CycleCard extends StatelessWidget {
  const V2CycleCard({
    super.key,
    required this.kicker,
    required this.title,
    required this.subtitle,
    this.value = 23,
    this.total = 60,
    this.onTap,
  });

  final String kicker;
  final String title;
  final String subtitle;
  final int value;
  final int total;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(V2Space.lg),
      decoration: BoxDecoration(
        color: V2Colors.white,
        borderRadius: BorderRadius.circular(V2Radius.card),
        boxShadow: V2Shadow.card,
      ),
      child: Row(
        children: [
          V2CycleRing(value: value, total: total),
          const SizedBox(width: V2Space.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  kicker,
                  style: V2Type.label.copyWith(color: V2Colors.muted),
                ),
                const SizedBox(height: V2Space.xs),
                Text(title, style: V2Type.h2),
                const SizedBox(height: V2Space.xs),
                Text(
                  subtitle,
                  style: V2Type.body.copyWith(color: V2Colors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(V2Radius.card),
        child: content,
      ),
    );
  }
}
