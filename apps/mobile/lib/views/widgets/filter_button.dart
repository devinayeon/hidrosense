import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    const activeColor = Color.fromRGBO(57, 198, 195, 1);
    const borderColor = Color.fromRGBO(229, 231, 235, 1);

    return AnimatedScale(
      scale: _pressed ? 0.94 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: CapsuleBadge(
          label: widget.label,
          textColor: widget.isSelected ? Colors.white : Colors.black87,
          backgroundColor: widget.isSelected ? activeColor : Colors.white,
          borderColor: widget.isSelected ? activeColor : borderColor,
          size: CapsuleSize.large,
          fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w600,
          onTap: widget.onTap,
          boxShadow: widget.isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}
