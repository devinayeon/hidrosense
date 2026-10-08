import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class CustomDropdownField extends StatelessWidget {
  final String label;
  final String hintText;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final String? errorText;

  const CustomDropdownField({
    super.key,
    required this.label,
    required this.hintText,
    required this.value,
    required this.items,
    required this.onChanged,
    this.errorText,
  });

  void _openModalPicker(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.modal),
            ),
          ),
          padding: EdgeInsets.only(
            top: AppSpacing.xs,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 5,
                margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: AppTypography.headline.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.borderSubtle),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, color: AppColors.borderSubtle),
                  itemBuilder: (_, index) {
                    final item = items[index];
                    final isSelected = item == value;
                    return InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onChanged(item);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 14,
                        ),
                        color: isSelected
                            ? AppColors.accentMintSoft.withOpacity(0.5)
                            : Colors.transparent,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item,
                                style: AppTypography.body.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? AppColors.primaryDarkTeal
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.primaryMint,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.subheadline.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        GestureDetector(
          onTap: () => _openModalPicker(context),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(AppRadius.input),
              border: Border.all(
                color: hasError ? AppColors.dangerRed : AppColors.borderLight,
                width: hasError ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    value != null && value!.isNotEmpty ? value! : hintText,
                    style: value != null && value!.isNotEmpty
                        ? AppTypography.body.copyWith(
                            color: AppColors.textPrimary,
                          )
                        : AppTypography.body.copyWith(
                            color: AppColors.textTertiary,
                          ),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: AppTypography.footnote.copyWith(
              color: AppColors.dangerRed,
            ),
          ),
        ],
      ],
    );
  }
}
