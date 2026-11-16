import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import 'v2_icon.dart';

/// Baris stok dari component set `StockItem` (lead 40, qty di kanan).
class V2StockItem extends StatelessWidget {
  const V2StockItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.quantity,
    this.icon = V2IconName.sprout,
    this.badge,
    this.onTap,
    this.divider = false,
  });

  final String title;
  final String subtitle;
  final String quantity;
  final V2IconName icon;
  final Widget? badge;
  final VoidCallback? onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: V2Space.lg,
        vertical: V2Space.md,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: V2Colors.blue50,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: V2Icon(icon, size: 22, color: V2Colors.blue700),
            ),
          ),
          const SizedBox(width: V2Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: V2Type.bodyStrong,
                ),
                const SizedBox(height: V2Space.xs),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: V2Type.label.copyWith(color: V2Colors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: V2Space.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(quantity, style: V2Type.bodyStrong),
              if (badge != null) ...[
                const SizedBox(height: V2Space.xs),
                badge!,
              ],
            ],
          ),
        ],
      ),
    );

    final wrapped = InkWell(
      onTap: onTap,
      child: Column(
        children: [
          content,
          if (divider)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: V2Space.lg),
              child: Divider(height: 1),
            ),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: V2Colors.white,
        borderRadius: BorderRadius.circular(V2Radius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : wrapped,
    );
  }
}
