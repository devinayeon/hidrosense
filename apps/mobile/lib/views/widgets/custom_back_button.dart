import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class CustomBackButton extends StatefulWidget {
  final VoidCallback? onTap;
  const CustomBackButton({super.key, this.onTap});

  @override
  State<CustomBackButton> createState() => _CustomBackButtonState();
}

class _CustomBackButtonState extends State<CustomBackButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.92 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          HapticFeedback.lightImpact();
          if (widget.onTap != null) {
            widget.onTap!();
          } else {
            Navigator.maybePop(context);
          }
        },
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.input),
            border: Border.all(
              color: AppColors.borderLight,
              width: 1,
            ),
            boxShadow: AppShadows.subtle,
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
            size: 20,
          ),
        ),
      ),
    );
  }
}
