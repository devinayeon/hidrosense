import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class RowInfoCardMd extends StatefulWidget {
  final Color backgroundColor;
  final Color? borderColor;
  final Widget child;
  final double? height;
  final double? width;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const RowInfoCardMd({
    super.key,
    required this.backgroundColor,
    this.borderColor,
    required this.child,
    this.height,
    this.width = double.infinity,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
  });

  @override
  State<RowInfoCardMd> createState() => _RowInfoCardMdState();
}

class _RowInfoCardMdState extends State<RowInfoCardMd> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isClickable = widget.onTap != null;

    final card = Material(
      color: Colors.transparent,
      child: Ink(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: widget.borderColor ?? AppColors.borderLight,
            width: 1,
          ),
          boxShadow: AppShadows.subtle,
        ),
        child: InkWell(
          onTap: widget.onTap == null
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  widget.onTap!();
                },
          onHighlightChanged: isClickable
              ? (value) => setState(() => _pressed = value)
              : null,
          borderRadius: BorderRadius.circular(AppRadius.card),
          splashColor: Colors.black.withValues(alpha: 0.04),
          highlightColor: Colors.black.withValues(alpha: 0.02),
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      ),
    );

    if (!isClickable) return card;

    return AnimatedScale(
      scale: _pressed ? 0.985 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: card,
    );
  }
}
