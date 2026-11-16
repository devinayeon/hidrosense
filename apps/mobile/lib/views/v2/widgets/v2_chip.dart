import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import 'v2_icon.dart';

/// Chip filter dari component set `Chip`.
class V2Chip extends StatelessWidget {
  const V2Chip({
    super.key,
    required this.label,
    this.selected = false,
    this.disabled = false,
    this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;
  final V2IconName? icon;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: V2Space.lg),
      decoration: BoxDecoration(
        color: disabled
            ? V2Colors.gray200
            : selected
            ? V2Colors.blue50
            : V2Colors.white,
        borderRadius: BorderRadius.circular(V2Radius.pill),
        border: Border.all(
          color: disabled
              ? V2Colors.gray200
              : selected
              ? V2Colors.blue700
              : V2Colors.slate400,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected || icon != null) ...[
            V2Icon(
              icon ?? V2IconName.check,
              size: 18,
              color: disabled ? V2Colors.muted : V2Colors.blue700,
            ),
            const SizedBox(width: V2Space.sm),
          ],
          Text(
            label,
            style: V2Type.label.copyWith(
              color: disabled ? V2Colors.muted : V2Colors.ink,
            ),
          ),
        ],
      ),
    );

    if (disabled || onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(V2Radius.pill),
        child: content,
      ),
    );
  }
}

/// Label peran dari component set `RoleChip`.
class V2RoleChip extends StatelessWidget {
  const V2RoleChip({
    super.key,
    required this.label,
    this.tone = V2RoleChipTone.blue,
  });

  final String label;
  final V2RoleChipTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      V2RoleChipTone.blue => (V2Colors.blue50, V2Colors.ink),
      V2RoleChipTone.neutral => (V2Colors.gray200, V2Colors.slate600),
      V2RoleChipTone.lime => (V2Colors.lime400, V2Colors.ink),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: V2Space.lg,
        vertical: V2Space.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(V2Radius.pill),
      ),
      child: Text(label, style: V2Type.label.copyWith(color: foreground)),
    );
  }
}

enum V2RoleChipTone { blue, neutral, lime }
