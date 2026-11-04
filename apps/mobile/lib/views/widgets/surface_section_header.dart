import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_surface_colors.dart';

/// Judul bagian dengan keterangan jumlah, mengikuti header daftar inventaris.
class SurfaceSectionHeader extends StatelessWidget {
  const SurfaceSectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = AppSurfaceColors.of(context);
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xxs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(title, style: AppTypography.headline.copyWith(color: colors.ink)),
        if (trailing != null)
          Text(
            trailing!,
            style: AppTypography.footnote.copyWith(color: colors.secondary),
          ),
      ],
    );
  }
}
