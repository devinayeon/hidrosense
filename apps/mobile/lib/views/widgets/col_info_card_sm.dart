import 'package:flutter/material.dart';

class ColInfoCardSm extends StatelessWidget {
  final Color backgroundColor;
  final Color borderColor;
  final Widget child;

  const ColInfoCardSm({
    super.key,
    required this.backgroundColor,
    required this.borderColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 101.33333587646484,
      height: 89,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor,
          width: 1.0,
        ),
      ),
      child: child,
    );
  }
}