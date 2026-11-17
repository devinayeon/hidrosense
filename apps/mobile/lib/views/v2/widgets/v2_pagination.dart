import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';

/// Indikator halaman dari component set `Pagination`.
class V2Pagination extends StatelessWidget {
  const V2Pagination({super.key, required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var dot = 0; dot < count; dot++) ...[
          if (dot > 0) const SizedBox(width: V2Space.sm),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: dot == index ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: dot == index ? V2Colors.ink : V2Colors.slate400,
              borderRadius: BorderRadius.circular(V2Radius.pill),
            ),
          ),
        ],
      ],
    );
  }
}
