import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import '../widgets/v2_skeleton.dart';

/// Kerangka pemuatan daftar meja (frame 6.3).
///
/// Empat kartu putih bersudut 24, masing-masing 80 tinggi: lingkaran 48 dan dua
/// garis teks. Sama seperti kerangka semaian; bentuknya dibuat sendiri di page
/// 06 supaya kepadatan tiap halaman bisa berbeda.
class V2MejaSkeleton extends StatelessWidget {
  const V2MejaSkeleton({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < count; index++) ...[
          if (index > 0) const SizedBox(height: V2Space.sm),
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
      child: Row(
        children: [
          const V2Skeleton.circle(size: 48),
          const SizedBox(width: V2Space.lg),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: const V2Skeleton.line(width: double.infinity),
                ),
                const SizedBox(height: V2Space.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: const V2Skeleton.line(width: double.infinity),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
