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
/// Struktur FigCraft: container 390x106, sudut atas 24, border gray200, tiap
/// tab 56px berisi pil ikon 56x32 dan label 14/20, lalu home indicator.
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
    // `DecoratedBox` paints the 1px top border inside the 106px frame without
    // adding it to the layout height (a `Container` border would make 107).
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: V2Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(V2Radius.card),
        ),
        border: Border(top: BorderSide(color: V2Colors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: V2Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tinggi 56 hanyalah minimum: pada skala huruf besar label tumbuh
            // dan bilah ikut menjadi lebih tinggi, bukan meluap.
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
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
    final foreground = active ? V2Colors.ink : V2Colors.muted;
    // Lima label berbagi lebar layar; skala huruf dibatasi 1,3 supaya
    // "Lainnya" tetap muat di layar 320 dp.
    final content = MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 56,
            height: 32,
            decoration: BoxDecoration(
              color: active ? V2Colors.lime400 : Colors.transparent,
              borderRadius: BorderRadius.circular(V2Radius.pill),
            ),
            child: Center(
              child: V2Icon(item.icon, size: V2Icons.size, color: foreground),
            ),
          ),
          const SizedBox(height: V2Space.xs),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: V2Type.label.copyWith(
              color: foreground,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}
