import 'package:flutter/material.dart';

class TopInfoContent extends StatelessWidget {
  final String topText;
  final String middleText;
  final String bottomText;
  final Color textColor;

  const TopInfoContent({
    super.key,
    required this.topText,
    required this.middleText,
    required this.bottomText,
    this.textColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          topText,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 10,
            height: 1.0,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          middleText,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w800,
            fontSize: 20,
            height: 1.0,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          bottomText,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 10,
            height: 1.0,
            color: textColor,
          ),
        ),
      ],
    );
  }
}