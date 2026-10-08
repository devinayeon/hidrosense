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
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(
          color: AppColors.borderLight,
          width: 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.search,
            color: AppColors.textTertiary,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: AppTypography.body.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: AppTypography.callout.copyWith(
                  fontWeight: FontWeight.w400,
                  color: AppColors.textTertiary,
                ),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
