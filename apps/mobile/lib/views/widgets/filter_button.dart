import 'package:flutter/material.dart';
import 'capsule_badge.dart';

class FilterButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    const activeColor = Color.fromRGBO(57, 198, 195, 1);
    const borderColor = Color.fromRGBO(229, 231, 235, 1);

    return CapsuleBadge(
      label: label,
      textColor: isSelected ? Colors.white : Colors.black87,
      backgroundColor: isSelected ? activeColor : Colors.white,
      borderColor: isSelected ? activeColor : borderColor,
      size: CapsuleSize.large,
      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
      onTap: onTap,
      boxShadow: isSelected
          ? [
              BoxShadow(
                color: activeColor.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ]
          : null,
    );
  }
}
