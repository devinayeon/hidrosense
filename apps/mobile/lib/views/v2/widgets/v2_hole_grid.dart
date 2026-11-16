import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';

/// Grid lubang meja tanam dari component set `HoleGrid`.
class V2HoleGrid extends StatelessWidget {
  const V2HoleGrid({
    super.key,
    required this.filled,
    required this.total,
    this.dot = 10,
    this.gap = 4,
  });

  final int filled;
  final int total;
  final double dot;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final perRow = ((constraints.maxWidth + gap) / (dot + gap))
            .floor()
            .clamp(1, total == 0 ? 1 : total);
        final rows = total == 0 ? 0 : (total / perRow).ceil();
        return SizedBox(
          height: rows == 0 ? 0 : rows * dot + (rows - 1) * gap,
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (var index = 0; index < total; index++)
                Container(
                  width: dot,
                  height: dot,
                  decoration: BoxDecoration(
                    color: index < filled ? V2Colors.blue500 : null,
                    shape: BoxShape.circle,
                    border: index < filled
                        ? null
                        : Border.all(color: V2Colors.border, width: 1.5),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Kartu meja dari component `GridCard`: nama + badge, ringkasan, grid lubang.
class V2GridCard extends StatelessWidget {
  const V2GridCard({
    super.key,
    required this.name,
    required this.summary,
    required this.filled,
    required this.total,
    this.badge,
    this.onTap,
  });

  final String name;
  final String summary;
  final int filled;
  final int total;
  final Widget? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(V2Space.xl),
      decoration: BoxDecoration(
        color: V2Colors.white,
        borderRadius: BorderRadius.circular(V2Radius.card),
        boxShadow: V2Shadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Text(name, style: V2Type.bodyStrong)),
              if (badge != null) ...[const SizedBox(width: V2Space.sm), badge!],
            ],
          ),
          const SizedBox(height: V2Space.sm),
          Text(summary, style: V2Type.h2),
          const SizedBox(height: V2Space.md),
          V2HoleGrid(filled: filled, total: total),
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
