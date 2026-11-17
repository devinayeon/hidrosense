import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import '../widgets/v2_skeleton.dart';

/// Rangka kartu beranda sebelum 2.1 tampil (frame 2.3 "Beranda memuat").
///
/// Bentuknya mengikuti susunan siap: sapaan + bel, hero 160, baris 80, dua petak
/// persegi, lalu kartu cuaca kalau perannya Petani.
class V2BerandaSkeleton extends StatelessWidget {
  const V2BerandaSkeleton({super.key, this.withWeather = true});

  final bool withWeather;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const V2Skeleton.block(width: 160, height: 32, radius: 16),
            const Spacer(),
            const V2Skeleton.circle(size: 48),
          ],
        ),
        const SizedBox(height: V2Space.lg),
        const V2Skeleton.block(height: 160, radius: V2Radius.sheet),
        const SizedBox(height: V2Space.lg),
        const V2Skeleton.block(height: 80, radius: V2Radius.card),
        const SizedBox(height: V2Space.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final size = (constraints.maxWidth - V2Space.lg) / 2;
            return Row(
              children: [
                V2Skeleton.block(
                  width: size,
                  height: size,
                  radius: V2Radius.card,
                ),
                const SizedBox(width: V2Space.lg),
                V2Skeleton.block(
                  width: size,
                  height: size,
                  radius: V2Radius.card,
                ),
              ],
            );
          },
        ),
        if (withWeather) ...[
          const SizedBox(height: V2Space.lg),
          const V2Skeleton.block(height: 80, radius: V2Radius.card),
        ],
      ],
    );
  }
}
