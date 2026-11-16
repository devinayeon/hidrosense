import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import 'v2_icon.dart';

enum V2BentoTone { blue, warning, success }

/// Petak ringkas dari component set `BentoTile` (163x163).
class V2BentoTile extends StatelessWidget {
  const V2BentoTile({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.tone = V2BentoTone.blue,
    this.size = 163,
    this.onTap,
  });

  final String value;
  final String label;
  final V2IconName icon;
  final V2BentoTone tone;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (boxBackground, iconColor) = switch (tone) {
      V2BentoTone.blue => (V2Colors.blue50, V2Colors.blue700),
      V2BentoTone.warning => (V2Colors.amber100, V2Colors.amber800),
      V2BentoTone.success => (V2Colors.green100, V2Colors.green700),
    };

    final content = Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(V2Space.lg),
      decoration: BoxDecoration(
        color: V2Colors.white,
        borderRadius: BorderRadius.circular(V2Radius.card),
        boxShadow: V2Shadow.card,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: boxBackground,
              borderRadius: BorderRadius.circular(V2Radius.iconBox),
            ),
            child: Center(child: V2Icon(icon, size: 22, color: iconColor)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: V2Type.h2),
              const SizedBox(height: 2),
              Text(label, style: V2Type.label.copyWith(color: V2Colors.muted)),
            ],
          ),
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

/// Batang diagram dari component `ChartBar`.
class V2ChartBar extends StatelessWidget {
  const V2ChartBar({
    super.key,
    required this.value,
    required this.label,
    this.barHeight = 80,
    this.color = V2Colors.blue500,
  });

  final String value;
  final String label;
  final double barHeight;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: V2Type.label.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: V2Space.xs),
        Container(
          width: 48,
          height: barHeight,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
        const SizedBox(height: V2Space.xs),
        Text(label, style: V2Type.label.copyWith(color: V2Colors.muted)),
      ],
    );
  }
}
