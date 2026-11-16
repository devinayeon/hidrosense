import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import 'v2_icon.dart';
import 'v2_list_item.dart';

class V2ChecklistItem {
  const V2ChecklistItem({
    required this.title,
    this.subtitle,
    this.icon = V2IconName.check,
  });

  final String title;
  final String? subtitle;
  final V2IconName icon;
}

/// Daftar langkah dari component `Checklist`.
class V2Checklist extends StatelessWidget {
  const V2Checklist({
    super.key,
    required this.title,
    required this.items,
    this.onItemTap,
  });

  final String title;
  final List<V2ChecklistItem> items;
  final ValueChanged<int>? onItemTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(V2Space.lg),
      decoration: BoxDecoration(
        color: V2Colors.blue50,
        borderRadius: BorderRadius.circular(V2Radius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: V2Type.h2),
          const SizedBox(height: V2Space.sm),
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0) const SizedBox(height: V2Space.sm),
            V2ListItem(
              title: items[index].title,
              subtitle: items[index].subtitle,
              icon: items[index].icon,
              iconTone: V2ListItemIconTone.blue,
              padding: const EdgeInsets.symmetric(horizontal: V2Space.lg),
              onTap: onItemTap == null ? null : () => onItemTap!(index),
            ),
          ],
        ],
      ),
    );
  }
}

/// Kartu cuaca ringkas dari component set `WeatherCard`.
class V2WeatherCard extends StatelessWidget {
  const V2WeatherCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: const BoxConstraints(minHeight: 80),
      padding: const EdgeInsets.all(V2Space.lg),
      decoration: BoxDecoration(
        color: V2Colors.white,
        borderRadius: BorderRadius.circular(V2Radius.card),
        boxShadow: V2Shadow.card,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: V2Colors.blue50,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: V2Icon(V2IconName.cloud, color: V2Colors.blue700),
            ),
          ),
          const SizedBox(width: V2Space.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: V2Type.bodyStrong),
                const SizedBox(height: V2Space.xs),
                Text(
                  subtitle,
                  style: V2Type.label.copyWith(color: V2Colors.muted),
                ),
              ],
            ),
          ),
          const V2Icon(V2IconName.chevronRight, color: V2Colors.muted),
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
