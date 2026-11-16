import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import 'v2_icon.dart';

/// Baris daftar dari component set `ListItem`.
class V2ListItem extends StatelessWidget {
  const V2ListItem({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconTone = V2ListItemIconTone.blue,
    this.trailing,
    this.showChevron = true,
    this.onTap,
    this.background = V2Colors.white,
    this.padding = const EdgeInsets.symmetric(horizontal: V2Space.lg),
  });

  final String title;
  final String? subtitle;
  final V2IconName? icon;
  final V2ListItemIconTone iconTone;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;
  final Color background;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final (leadBackground, leadColor) = switch (iconTone) {
      V2ListItemIconTone.blue => (V2Colors.blue50, V2Colors.blue700),
      V2ListItemIconTone.warning => (V2Colors.amber100, V2Colors.amber800),
      V2ListItemIconTone.success => (V2Colors.green100, V2Colors.green700),
      V2ListItemIconTone.neutral => (V2Colors.gray200, V2Colors.slate600),
    };

    final content = Container(
      constraints: const BoxConstraints(minHeight: 80),
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(V2Radius.card),
        border: background == V2Colors.white
            ? null
            : Border.all(color: V2Colors.border),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: leadBackground,
                shape: BoxShape.circle,
              ),
              child: Center(child: V2Icon(icon!, color: leadColor)),
            ),
            const SizedBox(width: V2Space.lg),
          ],
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
                if (subtitle != null) ...[
                  const SizedBox(height: V2Space.xs),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: V2Type.label.copyWith(color: V2Colors.muted),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: V2Space.md),
            trailing!,
          ],
          if (showChevron) ...[
            const SizedBox(width: V2Space.md),
            const V2Icon(V2IconName.chevronRight, color: V2Colors.muted),
          ],
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

enum V2ListItemIconTone { blue, warning, success, neutral }
