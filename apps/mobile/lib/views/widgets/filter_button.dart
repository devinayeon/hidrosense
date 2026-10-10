import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'capsule_badge.dart';

class FilterButton extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const FilterButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<FilterButton> createState() => _FilterButtonState();
}

class _FilterButtonState extends State<FilterButton> {
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    const activeColor = AppColors.primaryMint;
    const borderColor = AppColors.borderLight;

    return AnimatedScale(
      scale: _pressed ? 0.94 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOutCubic,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        child: InkWell(
          onFocusChange: (focused) => setState(() => _focused = focused),
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onTap();
          },
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: CapsuleBadge(
            label: widget.label,
            textColor: AppColors.textPrimary,
            backgroundColor: widget.isSelected
                ? activeColor
                : AppColors.cardSurface,
            borderColor: _focused
                ? AppColors.darkNavy
                : widget.isSelected
                ? activeColor
                : borderColor,
            size: CapsuleSize.large,
            fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w600,
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}
