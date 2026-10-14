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

    // Inset dari Scaffold: top = status bar + header, bottom = floating navbar.
    final insets = MediaQuery.paddingOf(context);
    final buttonHeight = 52 * MediaQuery.textScalerOf(context).scale(1);
    // Ruang untuk tombol "Mulai Penyemaian Baru" yang melayang di atas navbar
    final actionSpace = canWrite
        ? buttonHeight + AppSpacing.md + AppSpacing.sm
        : 0.0;

    return ColoredBox(
      color: AppColors.canvasWarm,
      child: Stack(
        children: [
          Positioned.fill(
            child: RefreshIndicator(
              edgeOffset: insets.top,
              onRefresh: refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  insets.top + AppSpacing.md,
                  AppSpacing.md,
                  insets.bottom + actionSpace + AppSpacing.md,
                ),
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

          // Tombol aksi melayang di atas navbar. Latar hanya fade tipis
          // (bukan kotak solid) supaya konten tetap tembus di belakangnya.
          if (canWrite)
            Positioned(
              left: 0,
              right: 0,
              bottom: insets.bottom,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.canvasWarm.withValues(alpha: 0),
                      AppColors.canvasWarm.withValues(alpha: 0.92),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: RowButton(
                    label: '+ Mulai Penyemaian Baru',
                    borderRadius: AppRadius.pill,
                    height: buttonHeight,
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
            ),
        ],
      ),
    );
  }
}
