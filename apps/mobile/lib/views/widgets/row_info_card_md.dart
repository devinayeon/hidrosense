import 'package:flutter/material.dart';

class RowInfoCardMd extends StatelessWidget {
  final Color backgroundColor;
  final Color borderColor;
  final Widget child;

  const RowInfoCardMd({
    super.key,
    required this.backgroundColor,
    required this.borderColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 328,
      height: 73,
      padding: const EdgeInsets.all(14),
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