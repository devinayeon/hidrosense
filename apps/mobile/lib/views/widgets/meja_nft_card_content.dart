// lib/views/widgets/meja_nft_card_content.dart
import 'package:flutter/material.dart';
import '../../models/meja_nft_model.dart';
import '../theme/app_theme.dart';
import 'capsule_badge.dart';

class MejaNftCardContent extends StatelessWidget {
  final MejaNft item;

  const MejaNftCardContent({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final isAktif = item.status == MejaStatus.aktif;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              item.name,
              style: AppTypography.headline.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            CapsuleBadge(
              label: isAktif ? 'Aktif' : 'Perawatan',
              textColor: isAktif ? AppColors.infoBlue : AppColors.warningOrange,
              backgroundColor: isAktif ? AppColors.infoBg : AppColors.warningBg,
              size: CapsuleSize.small,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (isAktif) ...[
          Text(
            'Kapasitas: ${item.capacityUsed} / ${item.capacityTotal} Lubang Terisi',
            style: AppTypography.caption1.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '${item.batchName ?? ""} • ${item.variety ?? ""} (${item.hss ?? 0} HSS)',
            style: AppTypography.caption1.copyWith(
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ] else ...[
          Text(
            'Kapasitas: Kosong (${item.maintenanceNote ?? "Dalam Perawatan"})',
            style: AppTypography.caption1.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (item.maintenanceEta != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              item.maintenanceEta!,
              style: AppTypography.caption2.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ],
    );
  }
}
