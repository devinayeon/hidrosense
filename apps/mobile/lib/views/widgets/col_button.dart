import 'package:flutter/material.dart';

class ColButton extends StatefulWidget {
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
  State<ColButton> createState() => _ColButtonState();
}

class _ColButtonState extends State<ColButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.975 : 1.0,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOutCubic,
      child: SizedBox(
        height: widget.height,
        child: Material(
          color: widget.backgroundColor,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: InkWell(
            onTap: widget.onPressed,
            onHighlightChanged: (value) => setState(() => _pressed = value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
            splashColor: widget.textColor.withOpacity(0.08),
            highlightColor: Colors.transparent,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: Border.all(color: widget.borderColor, width: 1.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                widget.text,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: widget.fontSize,
                  fontWeight: widget.fontWeight,
                  color: widget.textColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
