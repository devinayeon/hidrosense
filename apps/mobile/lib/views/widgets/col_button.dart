import 'package:flutter/material.dart';

class ColButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color textColor;
  final Color backgroundColor;
  final Color borderColor;
  final double height;
  final double borderRadius;
  final double fontSize;
  final FontWeight fontWeight;

  const ColButton({
    super.key,
    required this.text,
    this.onPressed,
    this.textColor = const Color.fromRGBO(57, 198, 195, 1),
    this.backgroundColor = Colors.white,
    this.borderColor = const Color.fromRGBO(57, 198, 195, 1),
    this.height = 48.0,
    this.borderRadius = 16.0,
    this.fontSize = 15.0,
    this.fontWeight = FontWeight.w700,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          side: BorderSide(color: borderColor, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          elevation: 0,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
