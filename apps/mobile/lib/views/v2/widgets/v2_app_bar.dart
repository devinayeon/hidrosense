import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import 'v2_icon.dart';

/// AppBar 64px dari component set `AppBar` (Type=Back).
class V2AppBar extends StatelessWidget {
  const V2AppBar({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
    this.background = V2Colors.canvas,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: V2Space.lg),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: onBack == null
                ? null
                : IconButton(
                    onPressed: onBack,
                    icon: const V2Icon(V2IconName.back),
                    tooltip: 'Kembali',
                    padding: EdgeInsets.zero,
                  ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: V2Type.h2,
            ),
          ),
          SizedBox(
            width: 48,
            height: 48,
            child: trailing == null ? null : Center(child: trailing),
          ),
        ],
      ),
    );
  }
}

/// Judul layar dari component set `ScreenHeader`.
class V2ScreenHeader extends StatelessWidget {
  const V2ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: V2Type.h1),
              if (subtitle != null) ...[
                const SizedBox(height: V2Space.xs),
                Text(
                  subtitle!,
                  style: V2Type.body.copyWith(color: V2Colors.muted),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: V2Space.md), trailing!],
      ],
    );
  }
}
