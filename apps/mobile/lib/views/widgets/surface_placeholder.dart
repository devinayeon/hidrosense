import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_surface_colors.dart';

/// Kerangka kartu saat data pertama kali dimuat.
class SurfacePlaceholder extends StatelessWidget {
  const SurfacePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppSurfaceColors.of(context);
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.mintSurface,
        borderRadius: BorderRadius.circular(AppRadius.badge),
      ),
    );

    return ExcludeSemantics(
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bar(88, 24),
            const SizedBox(height: AppSpacing.sm),
            bar(double.infinity, 56),
            const SizedBox(height: AppSpacing.sm),
            bar(144, 20),
          ],
        ),
      ),
    );
  }
}
