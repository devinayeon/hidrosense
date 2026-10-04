import 'package:flutter/material.dart';

class RowInfoCardMd extends StatelessWidget {
  final Color backgroundColor;
  final Color borderColor;
  final Widget child;
  final double? height;
  final double? width;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap; // Tambahkan onTap opsional

  const RowInfoCardMd({
    super.key,
    required this.backgroundColor,
    required this.borderColor,
    required this.child,
    this.height,
    this.width = double.infinity,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
