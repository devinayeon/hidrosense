import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_surface_colors.dart';
import 'capsule_badge.dart';
import 'feature_illustration.dart';

/// Kartu data panen dengan pola yang sama seperti kartu inventaris,
/// penyemaian, penjualan, dan meja NFT: badge status, ilustrasi fitur,
/// lalu ringkasan hasil panen atau estimasi batch.
class PanenCard extends StatelessWidget {
  const PanenCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.result,
    required this.completed,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String result;
  final bool completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppSurfaceColors.of(context);
    final accent = completed ? colors.teal : colors.warning;
    final badgeBackground = accent.withValues(alpha: 0.14);
    final badgeBorder = accent.withValues(alpha: 0.35);

    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        focusColor: colors.mintSurface,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: CapsuleBadge(
                        label: completed ? 'Selesai' : 'Mendatang',
                        textColor: accent,
                        backgroundColor: badgeBackground,
                        borderColor: badgeBorder,
                        size: CapsuleSize.medium,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    CupertinoIcons.chevron_right,
                    color: colors.secondary,
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              LayoutBuilder(
                builder: (context, constraints) {
                  final heading = Text(
                    title,
                    style: AppTypography.headline.copyWith(
                      color: colors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                  final art = FeatureIllustration(
                    asset: FeatureIllustration.harvest,
                    size: 64,
                  );
                  return constraints.maxWidth < 250 ||
                          MediaQuery.textScalerOf(context).scale(1) > 1.5
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            art,
                            const SizedBox(height: AppSpacing.xs),
                            heading,
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: heading),
                            const SizedBox(width: AppSpacing.sm),
                            art,
                          ],
                        );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle,
                style: AppTypography.subheadline.copyWith(
                  color: colors.secondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: completed
                      ? colors.mintSurface
                      : colors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  border: Border.all(
                    color: completed
                        ? colors.border
                        : colors.warning.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  result,
                  style: AppTypography.tabular(
                    AppTypography.caption1.copyWith(
                      color: colors.ink,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
