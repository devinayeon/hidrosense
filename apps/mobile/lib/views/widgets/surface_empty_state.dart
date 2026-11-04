import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_surface_colors.dart';
import 'feature_illustration.dart';

/// State kosong dengan ilustrasi, judul, penjelasan, dan satu aksi opsional.
class SurfaceEmptyState extends StatelessWidget {
  const SurfaceEmptyState({
    super.key,
    required this.illustration,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.illustrationSize = 144,
  });

  final String illustration;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double illustrationSize;

  @override
  Widget build(BuildContext context) {
    final colors = AppSurfaceColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      child: Column(
        children: [
          FeatureIllustration(asset: illustration, size: illustrationSize),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.title3.copyWith(color: colors.ink),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.subheadline.copyWith(color: colors.secondary),
          ),
          if (actionLabel != null && onAction != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: colors.teal,
                  minimumSize: const Size(44, 44),
                ),
                child: Text(actionLabel!),
              ),
            ),
        ],
      ),
    );
  }
}
