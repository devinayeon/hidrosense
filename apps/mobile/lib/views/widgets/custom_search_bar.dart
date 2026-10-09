import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CustomSearchBar extends StatelessWidget {
  final String placeholder;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final double? width;

  const CustomSearchBar({
    super.key,
    this.placeholder = 'Cari nama barang...',
    this.onChanged,
    this.controller,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      constraints: BoxConstraints(
        minHeight: 44 * MediaQuery.textScalerOf(context).scale(1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: AppColors.borderLight, width: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: AppTypography.body.copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: AppTypography.callout.copyWith(
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.xs,
                ),
                isCollapsed: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
