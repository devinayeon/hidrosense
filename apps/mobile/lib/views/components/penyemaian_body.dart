import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/connected_nursery_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../pages/info_seeding_page.dart';
import '../pages/seeding_form_page.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_search_bar.dart';
import '../widgets/row_info_card_md.dart';
import '../widgets/row_button.dart';
import '../widgets/seeding_card_content.dart';
import '../widgets/transfer_seedling_bottom_sheet.dart';

class PenyemaianBody extends ConsumerWidget {
  const PenyemaianBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider.select((state) => state.user));
    if (user == null || !user.permissions.contains('penyemaian:read')) {
      return const Center(child: Text('Penyemaian memerlukan izin baca.'));
    }
    final canWrite = user.permissions.contains('penyemaian:write');
    final state = ref.watch(connectedNurseryProvider);
    final refresh = ref.read(connectedNurseryProvider.notifier).refresh;
    final items = state.filteredRecords;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.canvasWarm,
      child: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (state.error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.dangerBg,
                          borderRadius: BorderRadius.circular(AppRadius.input),
                          border: Border.all(
                            color: AppColors.dangerRed.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 18,
                              color: AppColors.dangerRed,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                state.error!,
                                style: AppTypography.caption1.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    CustomSearchBar(
                      placeholder: 'Cari batch semaian...',
                      onChanged: (value) {
                        ref
                            .read(connectedNurseryProvider.notifier)
                            .setSearchQuery(value);
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (state.loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.0),
                          child: CircularProgressIndicator(
                            color: AppColors.primaryMint,
                          ),
                        ),
                      )
                    else if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32.0),
                        child: Center(
                          child: Text(
                            state.error != null && state.records.isEmpty
                                ? 'Data penyemaian belum dapat ditampilkan.'
                                : state.records.isEmpty
                                ? 'Belum ada batch penyemaian.'
                                : 'Penyemaian tidak ditemukan.',
                            style: AppTypography.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    else
                      ...items.map((item) {
                        final isReady = item.canTransfer;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: RowInfoCardMd(
                            backgroundColor: Colors.white,
                            borderColor: isReady
                                ? AppColors.warningOrange.withValues(
                                    alpha: 0.35,
                                  )
                                : AppColors.borderLight,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      InfoSeedingPage(sowingRecord: item),
                                ),
                              );
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SeedingCardContent(
                                  batchName: item.batchName,
                                  dateText: item.sowingDate,
                                  seedCountText: item.seedCountText,
                                  hssText: item.hssText,
                                  statusLabel: item.statusLabel,
                                  statusTextColor: AppColors.textPrimary,
                                  statusBgColor: isReady
                                      ? AppColors.warningBg
                                      : AppColors.accentMintSoft,
                                  statusBorderColor: isReady
                                      ? AppColors.warningOrange.withValues(
                                          alpha: 0.3,
                                        )
                                      : AppColors.primaryMint.withValues(
                                          alpha: 0.3,
                                        ),
                                  note: item.note,
                                ),
                                if (isReady && canWrite) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(44, 44),
                                        side: const BorderSide(
                                          color: AppColors.textPrimary,
                                          width: 1.2,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.pill,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.sm,
                                          vertical: AppSpacing.xxs,
                                        ),
                                        backgroundColor:
                                            AppColors.accentMintSoft,
                                      ),
                                      onPressed: () {
                                        TransferSeedlingBottomSheet.show(
                                          context,
                                          sowingRecord: item,
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 15,
                                        color: AppColors.primaryDarkTeal,
                                      ),
                                      label: Text(
                                        'Pindah ke Meja',
                                        style: AppTypography.caption1.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ),
          ),

          // Sticky Bottom Action Container (Apple HIG 52pt pill button)
          if (canWrite)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: const BoxDecoration(
                color: AppColors.canvasWarm,
                border: Border(
                  top: BorderSide(color: AppColors.borderSubtle, width: 0.5),
                ),
              ),
              child: SafeArea(
                top: false,
                child: RowButton(
                  label: '+ Mulai Penyemaian Baru',
                  borderRadius: AppRadius.pill,
                  height: 52 * MediaQuery.textScalerOf(context).scale(1),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SeedingFormPage(),
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
