// lib/views/components/panen_body.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/panen_viewmodel.dart';
import '../pages/laporan_panen_page.dart';
import '../pages/panen_form_page.dart';
import '../theme/app_theme.dart';
import '../widgets/filter_button.dart';
import '../widgets/panen_card.dart';
import '../widgets/row_button.dart';

class PanenBody extends ConsumerWidget {
  const PanenBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allPanenList = ref.watch(panenViewModelProvider);
    final activeFilter = ref.watch(panenFilterCategoryProvider);
    final panenList = ref.watch(filteredPanenListProvider);

    // Hitung jumlah dinamik untuk badge tab
    final upcomingCount = allPanenList.where((item) => item.isEstimasi).length;
    final completedCount = allPanenList
        .where((item) => !item.isEstimasi)
        .length;

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
                  // 1. Filter Tab Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        FilterButton(
                          label: 'Semua Data',
                          isSelected: activeFilter == PanenFilterCategory.all,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref
                                    .read(panenFilterCategoryProvider.notifier)
                                    .state =
                                PanenFilterCategory.all;
                          },
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        FilterButton(
                          label: 'Mendatang ($upcomingCount)',
                          isSelected:
                              activeFilter == PanenFilterCategory.upcoming,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref
                                    .read(panenFilterCategoryProvider.notifier)
                                    .state =
                                PanenFilterCategory.upcoming;
                          },
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        FilterButton(
                          label: 'Selesai ($completedCount)',
                          isSelected:
                              activeFilter == PanenFilterCategory.completed,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref
                                    .read(panenFilterCategoryProvider.notifier)
                                    .state =
                                PanenFilterCategory.completed;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 2. Daftar Panen Cards
                  if (panenList.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
                      child: Center(
                        child: Text(
                          'Tidak ada data panen.',
                          style: AppTypography.subheadline.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: panenList.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final panenItem = panenList[index];
                        return PanenCard(
                          item: panenItem,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    LaporanPanenPage(item: panenItem),
                              ),
                            );
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
          ),

          // 3. Bottom Button: + Catat Hasil Panen Baru (Apple HIG 52pt pill button)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            color: AppColors.canvasWarm,
            child: SafeArea(
              child: RowButton(
                label: '+ Catat Hasil Panen Baru',
                backgroundColor: AppColors.darkNavy,
                textColor: AppColors.accentLime,
                borderRadius: AppRadius.pill,
                height: 52,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PanenFormPage(),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
