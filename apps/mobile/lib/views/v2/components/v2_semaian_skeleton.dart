import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import '../widgets/v2_skeleton.dart';

/// Kerangka pemuatan daftar semaian (frame 5.3).
///
/// Empat kartu putih bersudut 24, masing-masing 80 tinggi: lingkaran 48 dan dua
/// garis teks. Bentuknya dibuat lokal di halaman ini supaya tiap halaman bebas
/// mengubah kepadatannya.
class V2SemaianSkeleton extends StatelessWidget {
  const V2SemaianSkeleton({super.key, this.count = 4});

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
