import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/connected_nursery_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../pages/info_seeding_page.dart';
import '../pages/seeding_form_page.dart';
import '../theme/app_theme.dart';
import '../widgets/app_surface_colors.dart';
import '../widgets/feature_illustration.dart';
import '../widgets/feature_overview_card.dart';
import '../widgets/row_button.dart';
import '../widgets/seeding_batch_card.dart';
import '../widgets/surface_empty_state.dart';
import '../widgets/surface_notice.dart';
import '../widgets/surface_placeholder.dart';
import '../widgets/surface_search_field.dart';
import '../widgets/surface_section_header.dart';
import '../widgets/transfer_seedling_bottom_sheet.dart';

class PenyemaianBody extends ConsumerStatefulWidget {
  const PenyemaianBody({super.key});

  @override
  ConsumerState<PenyemaianBody> createState() => _PenyemaianBodyState();
}

class _PenyemaianBodyState extends ConsumerState<PenyemaianBody> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetFilters(ConnectedNurseryViewModel notifier) {
    FocusScope.of(context).unfocus();
    _searchController.clear();
    notifier.setSearchQuery('');
    notifier.setFilterStatus(null);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider.select((state) => state.user));
    if (user == null || !user.permissions.contains('penyemaian:read')) {
      return const Center(child: Text('Penyemaian memerlukan izin baca.'));
    }

    final canWrite = user.permissions.contains('penyemaian:write');
    final state = ref.watch(connectedNurseryProvider);
    final notifier = ref.read(connectedNurseryProvider.notifier);
    final refresh = notifier.refresh;
    final items = state.filteredRecords;
    final colors = AppSurfaceColors.of(context);

    final insets = MediaQuery.paddingOf(context);
    final initialLoading = state.loading && state.records.isEmpty;
    final showAction = canWrite && View.of(context).viewInsets.bottom == 0;
    final buttonHeight = 52 * MediaQuery.textScalerOf(context).scale(1);
    final actionSpace = showAction ? buttonHeight + AppSpacing.xl : 0.0;

    final activeCount = state.records
        .where((item) => item.status == 'aktif')
        .length;
    final readyCount = state.records.where((item) => item.canTransfer).length;
    final finishedCount = state.records
        .where((item) => item.status == 'selesai')
        .length;

    final countLabel = initialLoading ? 'Memuat...' : '${items.length} batch';

    final failed = state.error != null && state.records.isEmpty;

    return ColoredBox(
      color: colors.canvas,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(bottom: actionSpace),
              child: RefreshIndicator(
                color: colors.teal,
                edgeOffset: insets.top,
                onRefresh: refresh,
                child: CustomScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        insets.top + AppSpacing.sm,
                        AppSpacing.lg,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (state.records.isNotEmpty || initialLoading) ...[
                              FeatureOverviewCard(
                                eyebrow: 'PENYEMAIAN',
                                title: initialLoading
                                    ? 'Memuat batch...'
                                    : 'Ruang semai',
                                subtitle: initialLoading
                                    ? 'Menyiapkan data dari layanan.'
                                    : '$activeCount batch aktif · '
                                          '$readyCount siap pindah',
                                detail: !initialLoading && finishedCount > 0
                                    ? '$finishedCount batch selesai'
                                    : null,
                                illustration: FeatureIllustration.nursery,
                              ),
                              const SizedBox(height: AppSpacing.xl),
                            ],
                            if (state.error != null)
                              SurfaceNotice(
                                icon: CupertinoIcons.exclamationmark_circle,
                                text: state.error!,
                                error: true,
                                onRetry: state.loading ? null : refresh,
                              ),
                            if (state.loading && state.records.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
                                child: Semantics(
                                  label: 'Memperbarui penyemaian',
                                  liveRegion: true,
                                  child: LinearProgressIndicator(
                                    color: colors.teal,
                                    backgroundColor: colors.mintSurface,
                                    minHeight: 2,
                                  ),
                                ),
                              ),
                            SurfaceSearchField(
                              controller: _searchController,
                              label: 'Cari batch semaian...',
                              query: state.searchQuery,
                              onChanged: notifier.setSearchQuery,
                              onClear: () {
                                _searchController.clear();
                                notifier.setSearchQuery('');
                              },
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _StatusChips(
                              selected: state.filterStatus,
                              colors: colors,
                              onSelect: notifier.setFilterStatus,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            SurfaceSectionHeader(
                              title: 'Daftar semaian',
                              trailing: countLabel,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                        ),
                      ),
                    ),
                    if (initialLoading)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        sliver: SliverList.builder(
                          itemCount: 3,
                          itemBuilder: (_, _) => const SurfacePlaceholder(),
                        ),
                      )
                    else if (items.isEmpty)
                      SliverToBoxAdapter(
                        child: SurfaceEmptyState(
                          illustration: failed || state.records.isEmpty
                              ? FeatureIllustration.emptyNursery
                              : FeatureIllustration.noResults,
                          title: failed
                              ? 'Data penyemaian belum dapat ditampilkan.'
                              : state.records.isEmpty
                              ? 'Belum ada batch penyemaian.'
                              : 'Penyemaian tidak ditemukan.',
                          message: failed
                              ? 'Periksa koneksi, lalu coba muat kembali.'
                              : state.records.isEmpty
                              ? 'Mulai batch pertama untuk mencatat umur dan '
                                    'kesiapan pindah bibit.'
                              : 'Coba nama batch lain atau hapus filter yang '
                                    'sedang aktif.',
                          actionLabel: failed
                              ? 'Coba lagi'
                              : state.records.isEmpty
                              ? null
                              : 'Hapus filter',
                          onAction: failed
                              ? refresh
                              : state.records.isEmpty
                              ? null
                              : () => _resetFilters(notifier),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        sliver: SliverList.separated(
                          itemCount: items.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return SeedingBatchCard(
                              key: ValueKey(item.id),
                              item: item,
                              canWrite: canWrite,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      InfoSeedingPage(sowingRecord: item),
                                ),
                              ),
                              onTransfer: () {
                                TransferSeedlingBottomSheet.show(
                                  context,
                                  sowingRecord: item,
                                );
                              },
                            );
                          },
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: SizedBox(height: insets.bottom + AppSpacing.sm),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (showAction)
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
                      colors.canvas.withValues(alpha: 0),
                      colors.canvas.withValues(alpha: 0.92),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: RowButton(
                    label: '+ Mulai Penyemaian Baru',
                    backgroundColor: AppColors.accentLime,
                    textColor: AppColors.darkNavy,
                    borderRadius: AppRadius.pill,
                    height: buttonHeight,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SeedingFormPage(),
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

/// Chip filter status batch, mengikuti pola chip kategori inventaris.
class _StatusChips extends StatelessWidget {
  const _StatusChips({
    required this.selected,
    required this.colors,
    required this.onSelect,
  });

  final String? selected;
  final AppSurfaceColors colors;
  final ValueChanged<String?> onSelect;

  static const _options = <(String?, String)>[
    (null, 'Semua'),
    ('aktif', 'Aktif'),
    ('selesai', 'Selesai tanam'),
  ];

  @override
  Widget build(BuildContext context) {
    final chipAnimation = MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : const AnimationStyle(
            duration: Duration(milliseconds: 140),
            reverseDuration: Duration(milliseconds: 100),
            curve: Curves.easeOutCubic,
          );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final option in _options)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: ChoiceChip(
                label: Text(option.$2),
                selected: selected == option.$1,
                showCheckmark: false,
                selectedColor: AppColors.accentLime,
                backgroundColor: colors.surface,
                labelStyle: AppTypography.subheadline.copyWith(
                  color: selected == option.$1
                      ? AppColors.darkNavy
                      : colors.ink,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide(
                  color: selected == option.$1
                      ? colors.teal
                      : colors.controlBorder,
                ),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                materialTapTargetSize: MaterialTapTargetSize.padded,
                chipAnimationStyle: ChipAnimationStyle(
                  selectAnimation: chipAnimation,
                  enableAnimation: chipAnimation,
                ),
                onSelected: (_) {
                  if (selected != option.$1) {
                    HapticFeedback.selectionClick();
                  }
                  onSelect(option.$1);
                },
              ),
            ),
        ],
      ),
    );
  }
}
