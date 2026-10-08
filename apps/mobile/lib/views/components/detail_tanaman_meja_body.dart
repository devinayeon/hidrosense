// lib/views/components/detail_tanaman_meja_body.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/meja_nft_model.dart';
import '../../viewmodels/baris_tanam_viewmodel.dart';
import '../pages/catat_kerusakan_page.dart';
import '../theme/app_theme.dart';
import '../widgets/baris_tanam_card.dart';
import '../widgets/filter_button.dart';

class DetailTanamanMejaBody extends ConsumerWidget {
  final MejaNft mejaItem;

  const DetailTanamanMejaBody({super.key, required this.mejaItem});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFilter = ref.watch(barisFilterCategoryProvider);
    final barisList = ref.watch(filteredBarisTanamListProvider);

    final String batchTitle =
        '${mejaItem.batchName ?? "Batch #03"} - ${mejaItem.variety ?? "Selada Grand Rapids"}';

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.canvasWarm,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Title & Subtitle Batch Info
                  Text(
                    batchTitle,
                    style: AppTypography.title3.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Berikut adalah data detail per baris / lubang tanam',
                    style: AppTypography.subheadline.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 2. Bar Filter Kategori
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        FilterButton(
                          label: 'Semua Baris',
                          isSelected: activeFilter == BarisFilterCategory.all,
                          onTap: () {
                            ref
                                    .read(barisFilterCategoryProvider.notifier)
                                    .state =
                                BarisFilterCategory.all;
                          },
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        FilterButton(
                          label: 'Kondisi Baik',
                          isSelected: activeFilter == BarisFilterCategory.good,
                          onTap: () {
                            ref
                                    .read(barisFilterCategoryProvider.notifier)
                                    .state =
                                BarisFilterCategory.good;
                          },
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        FilterButton(
                          label: 'Kondisi Rusak',
                          isSelected:
                              activeFilter == BarisFilterCategory.damaged,
                          onTap: () {
                            ref
                                    .read(barisFilterCategoryProvider.notifier)
                                    .state =
                                BarisFilterCategory.damaged;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 3. List Cards Baris Tanam
                  if (barisList.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                      child: Center(
                        child: Text(
                          'Tidak ada data baris tanam.',
                          style: AppTypography.body.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: barisList.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        return BarisTanamCard(item: barisList[index]);
                      },
                    ),
                ],
              ),
            ),
          ),

          // 4. Sticky Bottom Action Button
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: const BoxDecoration(
              color: AppColors.canvasWarm,
            ),
            child: SafeArea(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  side: const BorderSide(
                    color: AppColors.primaryMint,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  backgroundColor: AppColors.cardSurface,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          CatatKerusakanPage(mejaItem: mejaItem),
                    ),
                  );
                },
                child: Text(
                  'Catat Tanaman Rusak / Gagal',
                  style: AppTypography.headline.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryMint,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
