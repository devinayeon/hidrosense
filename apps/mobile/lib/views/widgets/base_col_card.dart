import 'package:flutter/material.dart';

class BaseColCard extends StatelessWidget {
  final Color backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double? width;  // Nullable: Jika null, mengikuti isi/parent
  final double? height; // Nullable: Jika null, dinamis mengikuti isi konten
  final Widget child;

  const BaseColCard({
    super.key,
    required this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1.0,
    this.borderRadius = 20.0,
    this.padding = const EdgeInsets.all(14.0),
    this.width,
    this.height,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: borderColor != null
            ? Border.all(
                color: borderColor!,
                width: borderWidth,
              )
            : null,
      ),
      child: child,
    );
  }
}