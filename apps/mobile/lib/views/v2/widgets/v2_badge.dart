import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import 'v2_icon.dart';

enum V2BadgeStatus { success, warning, error, info, neutral, pending }

/// Badge status dari component set `Badge` (6 status).
class V2Badge extends StatelessWidget {
  const V2Badge({
    super.key,
    required this.label,
    this.status = V2BadgeStatus.neutral,
    this.icon,
  });

  final String label;
  final V2BadgeStatus status;
  final V2IconName? icon;

  Color get _background => switch (status) {
    V2BadgeStatus.success => V2Colors.green100,
    V2BadgeStatus.warning => V2Colors.amber100,
    V2BadgeStatus.error => V2Colors.red100,
    V2BadgeStatus.info => V2Colors.blue50,
    V2BadgeStatus.neutral => V2Colors.gray200,
    V2BadgeStatus.pending => V2Colors.blue50,
  };

  Color get _foreground => switch (status) {
    V2BadgeStatus.success => V2Colors.green700,
    V2BadgeStatus.warning => V2Colors.amber800,
    V2BadgeStatus.error => V2Colors.red700,
    V2BadgeStatus.info || V2BadgeStatus.pending => V2Colors.blue700,
    V2BadgeStatus.neutral => V2Colors.slate600,
  };

  V2IconName get _defaultIcon => switch (status) {
    V2BadgeStatus.success => V2IconName.check,
    V2BadgeStatus.warning => V2IconName.warning,
    V2BadgeStatus.error => V2IconName.close,
    V2BadgeStatus.info => V2IconName.info,
    V2BadgeStatus.neutral => V2IconName.minus,
    V2BadgeStatus.pending => V2IconName.sync,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(
        left: V2Space.sm,
        right: V2Space.lg,
        top: V2Space.xs,
        bottom: V2Space.xs,
      ),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(V2Radius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          V2Icon(icon ?? _defaultIcon, size: V2Icons.small, color: _foreground),
          const SizedBox(width: V2Space.xs),
          // Lencana harus ikut membungkus di skala teks besar; tanpa `Flexible`
          // baris ini meluber keluar kartu (BUG-24).
          Flexible(
            child: Text(
              label,
              style: V2Type.label.copyWith(color: _foreground),
            ),
          ),
        ],
      ),
    );
  }
}
