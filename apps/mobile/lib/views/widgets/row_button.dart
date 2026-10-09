import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

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
    this.backgroundColor = AppColors.darkNavy,
    this.textColor = AppColors.accentLime,
    this.borderRadius = AppRadius.card,
    this.width = double.infinity,
    this.height = 52.0,
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
            onTap: widget.onTap == null
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    widget.onTap!();
                  },
            onHighlightChanged: (value) => setState(() => _pressed = value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
            splashColor: widget.textColor.withValues(alpha: 0.12),
            highlightColor: Colors.transparent,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: AppTypography.headline.copyWith(
                    color: widget.textColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
