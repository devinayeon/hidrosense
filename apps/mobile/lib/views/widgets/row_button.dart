import 'package:flutter/material.dart';

class RowButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color textColor;
  final double borderRadius;
  final double? width;
  final double height;

  const RowButton({
    super.key,
    required this.label,
    required this.onTap,
    this.backgroundColor = const Color.fromRGBO(23, 34, 49, 1),
    this.textColor = const Color.fromRGBO(221, 244, 90, 1),
    this.borderRadius = 16.0, // Pill/Capsule shape sesuai gambar
    this.width = double.infinity,
    this.height = 48.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: textColor,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}