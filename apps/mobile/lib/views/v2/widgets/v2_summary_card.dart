import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';

/// Kartu ringkasan biru dari component set `SummaryCard` (Type=Basic).
class V2SummaryCard extends StatelessWidget {
  const V2SummaryCard({
    super.key,
    required this.kicker,
    required this.value,
    this.meta,
    this.extra,
    this.badge,
    this.onTap,
  });

  final String kicker;
  final String value;
  final String? meta;
  final String? extra;
  final Widget? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(V2Space.xl),
      decoration: BoxDecoration(
        color: V2Colors.blue500,
        borderRadius: BorderRadius.circular(V2Radius.sheet),
        // `SummaryCard` (varian Basic & Progress) punya drop shadow yang sama
        // dengan `Shadow/Card`; sama seperti kartu putih "Riwayat".
        boxShadow: V2Shadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  kicker,
                  style: V2Type.label.copyWith(color: V2Colors.white),
                ),
              ),
              if (badge != null) ...[const SizedBox(width: V2Space.sm), badge!],
            ],
          ),
          const SizedBox(height: V2Space.sm),
          Text(value, style: V2Type.display.copyWith(color: V2Colors.white)),
          if (meta != null) ...[
            const SizedBox(height: V2Space.sm),
            Text(meta!, style: V2Type.label.copyWith(color: V2Colors.white)),
          ],
          if (extra != null) ...[
            const SizedBox(height: V2Space.sm),
            Text(
              extra!,
              style: V2Type.label.copyWith(
                color: V2Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
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
