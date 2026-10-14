import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/inventory_record.dart';
import '../../viewmodels/connected_inventory_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../pages/add_form_inventaris_page.dart';
import '../theme/app_theme.dart';
import '../widgets/inventory_card.dart';
import '../widgets/inventory_colors.dart';
import '../widgets/inventory_empty.dart';
import '../widgets/inventory_illustration.dart';
import '../widgets/inventory_notice.dart';
import '../widgets/inventory_placeholder.dart';
import '../widgets/inventory_stock_label.dart';
import '../widgets/inventory_stock_overview.dart';

class InventarisBody extends ConsumerStatefulWidget {
  const InventarisBody({super.key});

  @override
  ConsumerState<InventarisBody> createState() => _InventarisBodyState();
}

class _InventarisBodyState extends ConsumerState<InventarisBody> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _category;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _category = null;
    });
  }

  void _addItem() => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => const AddFormInventarisPage()),
  );

  void _showDetail(InventoryRecord item) {
    final colors = InventoryColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: false,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: colors.surface,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      builder: (context) => _InventoryDetailSheet(
        item: item,
        onEdit: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => AddFormInventarisPage(initialRecord: item),
            ),
          );
        },
        onDeactivate: () => _confirmDeactivate(context, item),
      ),
    );
  }

  void _confirmDeactivate(BuildContext sheetContext, InventoryRecord item) {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(connectedInventoryProvider.notifier);
    showDialog<void>(
      context: sheetContext,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Arsipkan Barang'),
        content: Text(
          'Apakah Anda yakin ingin mengarsipkan "${item.name}"? '
          'Barang ini tidak akan muncul di daftar aktif.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.warningOrange,
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              Navigator.pop(sheetContext);
              try {
                await notifier.deactivateItem(item.id);
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Barang "${item.name}" berhasil diarsipkan.',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Gagal mengarsipkan: ${serviceError(e)}'),
                    ),
                  );
                }
              }
            },
            child: const Text('Arsipkan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(connectedInventoryProvider, (_, next) {
      if (_category != null &&
          !next.activeCategories.contains(_category)) {
        setState(() => _category = null);
      }
    });

    final state = ref.watch(connectedInventoryProvider);
    final refresh = ref.read(connectedInventoryProvider.notifier).refresh;
    final colors = InventoryColors.of(context);

    final active = state.activeRecords;
    final categories = state.activeCategories;
    final selected = categories.contains(_category) ? _category : null;
    final filtered = active
        .where(
          (item) =>
              (selected == null || item.category == selected) &&
              item.name.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    final initialLoading = state.isInitialLoading;

    return ColoredBox(
      color: colors.canvas,
      child: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              color: colors.teal,
              onRefresh: refresh,
              child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (active.isNotEmpty || initialLoading) ...[
                            InventoryStockOverview(
                              items: active,
                              categories: categories.length,
                              loading: initialLoading,
                            ),
                            const SizedBox(height: 24),
                          ],
                          if (state.cached)
                            const InventoryNotice(
                              icon: CupertinoIcons.cloud_download,
                              text:
                                  'Salinan lokal. Saldo mungkin sudah berubah.',
                            ),
                          if (state.error != null)
                            InventoryNotice(
                              icon: CupertinoIcons.exclamationmark_circle,
                              text: state.error!,
                              error: true,
                              onRetry: state.loading || active.isEmpty
                                  ? null
                                  : refresh,
                            ),
                          if (state.fetchedAt != null)
                            _InventoryFetchedAt(fetchedAt: state.fetchedAt!),
                          _InventorySearchBar(
                            controller: _searchController,
                            query: _query,
                            colors: colors,
                            onChanged: (value) =>
                                setState(() => _query = value.trim()),
                            onClear: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                          const SizedBox(height: 12),
                          _InventoryCategoryChips(
                            categories: categories,
                            selected: selected,
                            colors: colors,
                            onSelect: (category) =>
                                setState(() => _category = category),
                          ),
                          const SizedBox(height: 20),
                          _InventoryListHeader(
                            initialLoading: initialLoading,
                            hasError: state.error != null,
                            activeIsEmpty: active.isEmpty,
                            filteredCount: filtered.length,
                            colors: colors,
                          ),
                          const SizedBox(height: 12),
                          if (state.loading)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Semantics(
                                label: 'Memperbarui inventaris',
                                liveRegion: true,
                                child: LinearProgressIndicator(
                                  color: colors.teal,
                                  backgroundColor: colors.mintSurface,
                                  minHeight: 2,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (initialLoading)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList.builder(
                        itemCount: 3,
                        itemBuilder: (_, _) => const InventoryPlaceholder(),
                      ),
                    )
                  else if (filtered.isEmpty)
                    SliverToBoxAdapter(
                      child: InventoryEmpty(
                        failed: state.error != null && active.isEmpty,
                        firstRun: active.isEmpty,
                        onReset: _clearFilters,
                        onRetry: refresh,
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      sliver: SliverList.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, index) {
                          final item = filtered[index];
                          return Padding(
                            key: ValueKey(item.id),
                            padding: const EdgeInsets.only(bottom: 12),
                            child: InventoryCard(
                              item: item,
                              onTap: () => _showDetail(item),
                            ),
                          );
                        },
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                ],
              ),
            ),
          ),
          if (View.of(context).viewInsets.bottom == 0)
            _InventoryAddButton(onTap: _addItem, colors: colors),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private sub-komponen (hanya dipakai di file ini)
// ---------------------------------------------------------------------------

/// Teks waktu terakhir data diperbarui.
class _InventoryFetchedAt extends StatelessWidget {
  const _InventoryFetchedAt({required this.fetchedAt});

  final DateTime fetchedAt;

  @override
  Widget build(BuildContext context) {
    final colors = InventoryColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        'Diperbarui ${DateFormat('dd/MM HH:mm').format(fetchedAt.toLocal())}',
        style: AppTypography.footnote.copyWith(color: colors.secondary),
      ),
    );
  }
}

/// TextField pencarian barang inventaris.
class _InventorySearchBar extends StatelessWidget {
  const _InventorySearchBar({
    required this.controller,
    required this.query,
    required this.colors,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final InventoryColors colors;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      cursorColor: colors.teal,
      style: AppTypography.body.copyWith(color: colors.ink),
      decoration: InputDecoration(
        filled: true,
        labelText: 'Cari barang',
        labelStyle: AppTypography.subheadline.copyWith(
          color: colors.secondary,
        ),
        floatingLabelStyle: TextStyle(color: colors.teal),
        fillColor: colors.surface,
        prefixIcon: Icon(
          CupertinoIcons.search,
          color: colors.secondary,
          size: 22,
        ),
        suffixIcon: query.isEmpty
            ? null
            : IconButton(
                tooltip: 'Hapus pencarian',
                icon: Icon(
                  CupertinoIcons.xmark_circle_fill,
                  color: colors.secondary,
                  size: 20,
                ),
                onPressed: onClear,
              ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: colors.controlBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: colors.teal, width: 2),
        ),
      ),
      onChanged: onChanged,
    );
  }
}

/// Baris chip filter kategori dengan horizontal scroll.
class _InventoryCategoryChips extends StatelessWidget {
  const _InventoryCategoryChips({
    required this.categories,
    required this.selected,
    required this.colors,
    required this.onSelect,
  });

  final List<String> categories;
  final String? selected;
  final InventoryColors colors;
  final ValueChanged<String?> onSelect;

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
          for (final category in <String?>[null, ...categories])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(category ?? 'Semua'),
                selected: selected == category,
                showCheckmark: false,
                selectedColor: AppColors.accentLime,
                backgroundColor: colors.surface,
                labelStyle: AppTypography.subheadline.copyWith(
                  color: selected == category
                      ? AppColors.darkNavy
                      : colors.ink,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide(
                  color: selected == category
                      ? colors.teal
                      : colors.controlBorder,
                ),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                materialTapTargetSize: MaterialTapTargetSize.padded,
                chipAnimationStyle: ChipAnimationStyle(
                  selectAnimation: chipAnimation,
                  enableAnimation: chipAnimation,
                ),
                onSelected: (_) {
                  if (selected != category) {
                    HapticFeedback.selectionClick();
                  }
                  onSelect(category);
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Header "Daftar barang" beserta counter jumlah item yang ditampilkan.
class _InventoryListHeader extends StatelessWidget {
  const _InventoryListHeader({
    required this.initialLoading,
    required this.hasError,
    required this.activeIsEmpty,
    required this.filteredCount,
    required this.colors,
  });

  final bool initialLoading;
  final bool hasError;
  final bool activeIsEmpty;
  final int filteredCount;
  final InventoryColors colors;

  @override
  Widget build(BuildContext context) {
    final countLabel = initialLoading
        ? 'Memuat...'
        : hasError && activeIsEmpty
        ? 'Belum dimuat'
        : '$filteredCount barang';

    return Wrap(
      spacing: 12,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Daftar barang',
          style: AppTypography.headline.copyWith(color: colors.ink),
        ),
        Text(
          countLabel,
          style: AppTypography.footnote.copyWith(color: colors.secondary),
        ),
      ],
    );
  }
}

/// Tombol "Tambah barang" di bagian bawah halaman.
class _InventoryAddButton extends StatelessWidget {
  const _InventoryAddButton({required this.onTap, required this.colors});

  final VoidCallback onTap;
  final InventoryColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: colors.canvas,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accentLime,
            foregroundColor: AppColors.darkNavy,
            minimumSize: const Size(0, 52),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: const StadiumBorder(),
            textStyle: AppTypography.headline,
          ),
          onPressed: onTap,
          icon: const Icon(CupertinoIcons.add, size: 20),
          label: const Text('Tambah barang'),
        ),
      ),
    );
  }
}

/// Bottom sheet detail item inventaris dengan tombol aksi.
class _InventoryDetailSheet extends StatelessWidget {
  const _InventoryDetailSheet({
    required this.item,
    required this.onEdit,
    required this.onDeactivate,
  });

  final InventoryRecord item;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    final colors = InventoryColors.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InventoryIllustration(
              asset: InventoryIllustration.forItem(item),
              size: 72,
            ),
            const SizedBox(height: 8),
            Text(
              item.name,
              style: AppTypography.title2.copyWith(color: colors.ink),
            ),
            const SizedBox(height: 6),
            Text(
              'Jenis: ${item.category}',
              style: AppTypography.subheadline.copyWith(
                color: colors.secondary,
              ),
            ),
            const SizedBox(height: 16),
            SelectableText(
              'Saldo: ${item.formattedStock}',
              style: AppTypography.tabular(
                AppTypography.title3.copyWith(color: colors.ink),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.minimum == null
                  ? 'Stok minimum belum ditetapkan.'
                  : 'Stok minimum: ${item.minimum} ${item.unit}',
              style: AppTypography.subheadline.copyWith(
                color: colors.secondary,
              ),
            ),
            const SizedBox(height: 10),
            InventoryStockLabel(item: item),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.ink,
                      side: BorderSide(color: colors.controlBorder),
                      minimumSize: const Size(0, 48),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: onEdit,
                    child: const Text('Ubah'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.warningOrange,
                      side: const BorderSide(color: AppColors.warningOrange),
                      minimumSize: const Size(0, 48),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: onDeactivate,
                    child: const Text('Arsipkan'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.teal,
                      foregroundColor: colors.onTeal,
                      minimumSize: const Size(0, 48),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Tutup'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
