import 'package:flutter/material.dart';

class RowInfoCardMd extends StatelessWidget {
  final Color backgroundColor;
  final Color borderColor;
  final Widget child;
  final double? height; // Dibuat nullable (opsional)
  final double? width;  // Dibuat nullable (opsional)
  final EdgeInsetsGeometry padding;

  const RowInfoCardMd({
    super.key,
    required this.backgroundColor,
    required this.borderColor,
    required this.child,
    this.height, // Jika null, tingginya akan otomatis menyesuaikan isinya
    this.width = double.infinity, // Default menyesuaikan lebar layar/parent
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor,
          width: 1.5,
        ),
      ),
      child: child,
    );
  }
}