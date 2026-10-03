import 'package:flutter/material.dart';

class CardIconBox extends StatelessWidget {
  final IconData iconData;
  final Color backgroundColor;
  final Color iconColor;
  final double width;
  final double height;
  final double borderRadius;
  final double iconSize;

  const CardIconBox({
    super.key,
    required this.iconData,
    required this.backgroundColor,
    required this.iconColor,
    this.width = 36.0,
    this.height = 36.0,
    this.borderRadius = 12.0,
    this.iconSize = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: iconSize,
      ),
    );
  }
}