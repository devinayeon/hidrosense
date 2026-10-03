import 'package:flutter/material.dart';

enum CategoryBadgeSize { small, medium, large }

class CategoryBadge extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color backgroundColor;
  final CategoryBadgeSize size;

  const CategoryBadge({
    super.key,
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    this.size = CategoryBadgeSize.small,
  });

  @override
  Widget build(BuildContext context) {
    // Penyesuaian font size & padding berdasarkan variasi ukuran
    final double fontSize;
    final EdgeInsetsGeometry padding;

    switch (size) {
      case CategoryBadgeSize.small:
        fontSize = 10;
        padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3);
        break;
      case CategoryBadgeSize.medium:
        fontSize = 12;
        padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4);
        break;
      case CategoryBadgeSize.large:
        fontSize = 14;
        padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
        break;
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: fontSize,
          color: textColor,
          height: 1.0,
        ),
      ),
    );
  }
}
