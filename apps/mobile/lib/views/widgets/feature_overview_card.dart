import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_surface_colors.dart';
import 'feature_illustration.dart';

/// Kartu ringkasan di bagian atas layar, mengikuti pola kartu inventaris:
/// permukaan mint, teks utama, dan satu ilustrasi fitur.
///
/// Layout adaptif: ilustrasi di samping pada layar lebar, di atas teks pada
/// layar sempit atau saat ukuran teks diperbesar.
class FeatureOverviewCard extends StatelessWidget {
  const FeatureOverviewCard({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.detail,
    this.illustration = FeatureIllustration.inventory,
    this.illustrationSize = 112,
    this.titleStyle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final String? detail;
  final String illustration;
  final double illustrationSize;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final colors = AppSurfaceColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.mintSurface,
        borderRadius: BorderRadius.circular(AppRadius.modal),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.3;
          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: AppTypography.footnote.copyWith(
                  color: colors.teal,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                title,
                style: (titleStyle ?? AppTypography.title2).copyWith(
                  color: colors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle,
                style: AppTypography.subheadline.copyWith(
                  color: colors.secondary,
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  detail!,
                  style: AppTypography.footnote.copyWith(
                    color: colors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          );
          final art = TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            builder: (_, value, child) => Opacity(opacity: value, child: child),
            child: FeatureIllustration(
              asset: illustration,
              size: illustrationSize,
            ),
          );
          return compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    art,
                    const SizedBox(height: AppSpacing.sm),
                    text,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: text),
                    const SizedBox(width: AppSpacing.sm),
                    art,
                  ],
                );
        },
      ),
    );
  }
}
