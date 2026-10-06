import 'package:flutter/material.dart';

class RowButton extends StatefulWidget {
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
    this.borderRadius = 16.0,
    this.width = double.infinity,
    this.height = 48.0,
  });

  @override
  State<RowButton> createState() => _RowButtonState();
}

class _RowButtonState extends State<RowButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.975 : 1.0,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOutCubic,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Material(
          color: widget.backgroundColor,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (value) => setState(() => _pressed = value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
            splashColor: widget.textColor.withOpacity(0.12),
            highlightColor: Colors.transparent,
            child: Center(
              child: Text(
                widget.label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: widget.textColor,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}