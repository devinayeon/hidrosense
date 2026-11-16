import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import 'v2_icon.dart';
import 'v2_status_bar.dart';

class V2TabItem {
  const V2TabItem({required this.label, required this.icon});

  final String label;
  final V2IconName icon;
}

/// Tab bar bawah dari component set `TabBar`.
///
/// Struktur FigCraft: container 390x106, sudut atas 24, border gray200,
/// lima tab 56px, lalu home indicator.
class V2TabBar extends StatelessWidget {
  const V2TabBar({
    super.key,
    required this.items,
    required this.activeIndex,
    this.onTap,
  });

  final List<V2TabItem> items;
  final int activeIndex;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: V2Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(V2Radius.card),
        ),
        border: Border(top: BorderSide(color: V2Colors.border)),
      ),
      padding: const EdgeInsets.only(top: V2Space.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 56,
            child: Row(
              children: [
                for (var index = 0; index < items.length; index++)
                  Expanded(
                    child: _Tab(
                      item: items[index],
                      active: index == activeIndex,
                      onTap: onTap == null ? null : () => onTap!(index),
                    ),
                  ),
              ],
            ),
          ),
          const V2HomeIndicator(),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.item, required this.active, this.onTap});

  final V2TabItem item;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: V2Space.md),
          decoration: BoxDecoration(
            color: active ? V2Colors.lime400 : Colors.transparent,
            borderRadius: BorderRadius.circular(V2Radius.pill),
          ),
          child: Center(
            child: V2Icon(
              item.icon,
              size: 20,
              color: active ? V2Colors.ink : V2Colors.slate500,
            ),
          ),
        ),
        const SizedBox(height: V2Space.xs),
        Text(
          item.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: V2Type.caption.copyWith(
            color: active ? V2Colors.ink : V2Colors.slate500,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            fontSize: 12,
            height: 16 / 12,
          ),
        ),
      ],
    );

    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}
