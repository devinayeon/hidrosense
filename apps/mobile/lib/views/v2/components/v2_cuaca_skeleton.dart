import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import '../widgets/v2_skeleton.dart';

/// Kerangka pemuatan cuaca (frame 10.6).
///
/// Tiga kartu putih 80 tinggi dengan jarak 16: lingkaran 48 dan dua garis
/// teks 180/120. Kerangka ini menggantikan lokasi dan segmen selama memuat.
class V2CuacaSkeleton extends StatelessWidget {
  const V2CuacaSkeleton({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < count; index++) ...[
          if (index > 0) const SizedBox(height: V2Space.lg),
          const _SkeletonCard(),
        ],
      ],
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: V2Space.lg),
      decoration: BoxDecoration(
        color: V2Colors.white,
        borderRadius: BorderRadius.circular(V2Radius.card),
      ),
      child: const Row(
        children: [
          V2Skeleton.circle(size: 48),
          SizedBox(width: V2Space.lg),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              V2Skeleton.line(width: 180),
              SizedBox(height: V2Space.sm),
              V2Skeleton.line(width: 120),
            ],
          ),
        ],
      ),
    );
  }
}