import 'package:flutter/material.dart';

class InfoCardMd extends StatelessWidget {
  final Color backgroundColor;
  final String topText;
  final String middleText;
  final String bottomText;
  final Color textColor;

  const InfoCardMd({
    super.key,
    required this.backgroundColor,
    required this.topText,
    required this.middleText,
    required this.bottomText,
    this.textColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 158,
      height: 89,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text Atas
          Text(
            topText,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600, // Semi Bold
              fontSize: 10,
              height: 1.0,
              color: textColor,
            ),
          ),
          // Text Tengah
          Text(
            middleText,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800, // Extra Bold
              fontSize: 20,
              height: 1.0,
              color: textColor,
            ),
          ),
          // Text Bawah
          Text(
            bottomText,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600, // Semi Bold
              fontSize: 10,
              height: 1.0,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}