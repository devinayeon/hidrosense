import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum CapsuleSize { small, medium, large }

class CapsuleBadge extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color backgroundColor;
  final Color? borderColor;
  final CapsuleSize size;
  final FontWeight? fontWeight;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;

  const CapsuleBadge({
    super.key,
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    this.borderColor,
    this.size = CapsuleSize.small,
    this.fontWeight,
    this.boxShadow,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Preset ukuran berdasarkan CapsuleSize
    final double fontSize;
    final EdgeInsetsGeometry padding;
    final double defaultBorderWidth;

    switch (size) {
      case CapsuleSize.small:
        fontSize = 12;
        padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5);
        defaultBorderWidth = 1.0;
        break;
      case CapsuleSize.medium:
        fontSize = 12;
        padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4);
        defaultBorderWidth = 1.0;
        break;
      case CapsuleSize.large:
        fontSize = 12;
        padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6);
        defaultBorderWidth = 1.5;
        break;
    }

    Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: defaultBorderWidth)
            : null,
        boxShadow: boxShadow,
      ),
      child: Text(
        label,
        style: AppTypography.caption1.copyWith(
          fontWeight: fontWeight ?? FontWeight.w600,
          fontSize: fontSize,
          color: textColor,
          height: 1.2,
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }

    return content;
  }
}
