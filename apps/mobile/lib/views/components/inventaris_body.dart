import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/inventory_record.dart';
import '../../viewmodels/connected_inventory_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../pages/account_page.dart';
import '../pages/add_form_inventaris_page.dart';
import '../theme/app_theme.dart';
import '../widgets/inventory_illustration.dart';

class InventoryHeader extends ConsumerWidget implements PreferredSizeWidget {
  const InventoryHeader({super.key});
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = _InventoryColors.of(context);
    final loading = ref.watch(
      connectedInventoryProvider.select((s) => s.loading),
    );
    return AppBar(
      backgroundColor: colors.canvas,
      foregroundColor: colors.ink,
      systemOverlayStyle: colors.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 20,
      title: Text(
        'Inventaris',
        style: AppTypography.title3.copyWith(
          color: colors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Perbarui inventaris',
          onPressed: loading
              ? null
              : ref.read(connectedInventoryProvider.notifier).refresh,
          icon: const Icon(CupertinoIcons.arrow_clockwise, size: 22),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 16),
          child: IconButton(
            tooltip: 'Buka akun',
            style: IconButton.styleFrom(
              backgroundColor: colors.mintSurface,
              minimumSize: const Size(44, 44),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const AccountPage()),
            ),
            icon: const InventoryIllustration(
              asset: InventoryIllustration.avatar,
              size: 34,
            ),
          ),
        ),
      ],
    );
  }
}

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
    final colors = _InventoryColors.of(context);
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
      builder: (context) => SafeArea(
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
              _StockLabel(item: item),
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
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                AddFormInventarisPage(initialRecord: item),
                          ),
                        );
                      },
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
                      onPressed: () => _confirmDeactivate(context, item),
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
          'Apakah Anda yakin ingin mengarsipkan "${item.name}"? Barang ini tidak akan muncul di daftar aktif.',
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
          !next.records.any(
            (item) => item.active && item.category == _category,
          )) {
        setState(() => _category = null);
      }
    });
    final state = ref.watch(connectedInventoryProvider);
    final refresh = ref.read(connectedInventoryProvider.notifier).refresh;
    final colors = _InventoryColors.of(context);
    final active = state.records.where((item) => item.active).toList();
    final categories = active.map((item) => item.category).toSet().toList()
      ..sort();
    final selected = categories.contains(_category) ? _category : null;
    final filtered = active
        .where(
          (item) =>
              (selected == null || item.category == selected) &&
              item.name.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    final initialLoading = state.loading && active.isEmpty;
    final chipAnimation = MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : const AnimationStyle(
            duration: Duration(milliseconds: 140),
            reverseDuration: Duration(milliseconds: 100),
            curve: Curves.easeOutCubic,
          );

    return ColoredBox(
      color: colors.canvas,
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
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
                              _StockOverview(
                                items: active,
                                categories: categories.length,
                                loading: initialLoading,
                              ),
                              const SizedBox(height: 24),
                            ],
                            if (state.cached)
                              const _InventoryNotice(
                                icon: CupertinoIcons.cloud_download,
                                text:
                                    'Salinan lokal. Saldo mungkin sudah berubah.',
                              ),
                            if (state.error != null)
                              _InventoryNotice(
                                icon: CupertinoIcons.exclamationmark_circle,
                                text: state.error!,
                                error: true,
                                onRetry: state.loading || active.isEmpty
                                    ? null
                                    : refresh,
                              ),
                            if (state.fetchedAt != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Text(
                                  'Diperbarui ${DateFormat('dd/MM HH:mm').format(state.fetchedAt!.toLocal())}',
                                  style: AppTypography.footnote.copyWith(
                                    color: colors.secondary,
                                  ),
                                ),
                              ),
                            TextField(
                              controller: _searchController,
                              cursorColor: colors.teal,
                              style: AppTypography.body.copyWith(
                                color: colors.ink,
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                labelText: 'Cari barang',
                                labelStyle: AppTypography.subheadline.copyWith(
                                  color: colors.secondary,
                                ),
                                floatingLabelStyle: TextStyle(
                                  color: colors.teal,
                                ),
                                fillColor: colors.surface,
                                prefixIcon: Icon(
                                  CupertinoIcons.search,
                                  color: colors.secondary,
                                  size: 22,
                                ),
                                suffixIcon: _query.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Hapus pencarian',
                                        icon: Icon(
                                          CupertinoIcons.xmark_circle_fill,
                                          color: colors.secondary,
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _query = '');
                                        },
                                      ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.input,
                                  ),
                                  borderSide: BorderSide(
                                    color: colors.controlBorder,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.input,
                                  ),
                                  borderSide: BorderSide(
                                    color: colors.teal,
                                    width: 2,
                                  ),
                                ),
                              ),
                              onChanged: (value) =>
                                  setState(() => _query = value.trim()),
                            ),
                            const SizedBox(height: 12),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (final category in <String?>[
                                    null,
                                    ...categories,
                                  ])
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ChoiceChip(
                                        label: Text(category ?? 'Semua'),
                                        selected: selected == category,
                                        showCheckmark: false,
                                        selectedColor: AppColors.accentLime,
                                        backgroundColor: colors.surface,
                                        labelStyle: AppTypography.subheadline
                                            .copyWith(
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
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.padded,
                                        chipAnimationStyle: ChipAnimationStyle(
                                          selectAnimation: chipAnimation,
                                          enableAnimation: chipAnimation,
                                        ),
                                        onSelected: (_) {
                                          if (selected != category) {
                                            HapticFeedback.selectionClick();
                                          }
                                          setState(() => _category = category);
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'Daftar barang',
                                  style: AppTypography.headline.copyWith(
                                    color: colors.ink,
                                  ),
                                ),
                                Text(
                                  initialLoading
                                      ? 'Memuat...'
                                      : state.error != null && active.isEmpty
                                      ? 'Belum dimuat'
                                      : '${filtered.length} barang',
                                  style: AppTypography.footnote.copyWith(
                                    color: colors.secondary,
                                  ),
                                ),
                              ],
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
                          itemBuilder: (_, _) => const _InventoryPlaceholder(),
                        ),
                      )
                    else if (filtered.isEmpty)
                      SliverToBoxAdapter(
                        child: _InventoryEmpty(
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
                              child: _InventoryCard(
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
              Container(
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: const StadiumBorder(),
                      textStyle: AppTypography.headline,
                    ),
                    onPressed: _addItem,
                    icon: const Icon(CupertinoIcons.add, size: 20),
                    label: const Text('Tambah barang'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StockOverview extends StatelessWidget {
  const _StockOverview({
    required this.items,
    required this.categories,
    required this.loading,
  });
  final List<InventoryRecord> items;
  final int categories;
  final bool loading;
  @override
  Widget build(BuildContext context) {
    final colors = _InventoryColors.of(context);
    final attention = items
        .where((item) => item.isLow || item.isOutOfStock)
        .length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.mintSurface,
        borderRadius: BorderRadius.circular(AppRadius.modal),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 280 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.3;
          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Persediaan\nkebunmu',
                style: AppTypography.title2.copyWith(
                  color: colors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                loading
                    ? 'Memuat persediaan...'
                    : '${items.length} barang · $categories kategori',
                style: AppTypography.subheadline.copyWith(
                  color: colors.secondary,
                ),
              ),
              if (!loading && attention > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '$attention barang perlu perhatian',
                    style: AppTypography.footnote.copyWith(
                      color: colors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          );
          final art = TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            builder: (_, value, child) => Opacity(opacity: value, child: child),
            child: const InventoryIllustration(
              asset: InventoryIllustration.overview,
              size: 112,
            ),
          );
          return compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [art, const SizedBox(height: 12), text],
                )
              : Row(
                  children: [
                    Expanded(child: text),
                    const SizedBox(width: 8),
                    art,
                  ],
                );
        },
      ),
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({required this.item, required this.onTap});
  final InventoryRecord item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = _InventoryColors.of(context);
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: colors.mintSurface,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                            bottomRight: Radius.circular(12),
                          ),
                        ),
                        child: Text(
                          item.category,
                          style: AppTypography.footnote.copyWith(
                            color: colors.teal,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    CupertinoIcons.chevron_right,
                    color: colors.secondary,
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final title = Text(
                    item.name,
                    style: AppTypography.headline.copyWith(
                      color: colors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                  final art = InventoryIllustration(
                    asset: InventoryIllustration.forItem(item),
                    size: 72,
                  );
                  return constraints.maxWidth < 250 ||
                          MediaQuery.textScalerOf(context).scale(1) > 1.5
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [art, const SizedBox(height: 8), title],
                        )
                      : Row(
                          children: [
                            Expanded(child: title),
                            const SizedBox(width: 12),
                            art,
                          ],
                        );
                },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    item.formattedStock,
                    style: AppTypography.tabular(
                      AppTypography.headline.copyWith(color: colors.ink),
                    ),
                  ),
                  _StockLabel(item: item),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockLabel extends StatelessWidget {
  const _StockLabel({required this.item});
  final InventoryRecord item;
  @override
  Widget build(BuildContext context) {
    final colors = _InventoryColors.of(context);
    final label = item.isOutOfStock
        ? 'Stok habis'
        : item.isLow
        ? 'Stok menipis'
        : item.minimum == null
        ? 'Stok tersedia'
        : 'Stok mencukupi';
    final color = item.isOutOfStock
        ? colors.error
        : item.isLow
        ? colors.warning
        : colors.teal;
    return Text(
      label,
      style: AppTypography.footnote.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _InventoryNotice extends StatelessWidget {
  const _InventoryNotice({
    required this.icon,
    required this.text,
    this.error = false,
    this.onRetry,
  });
  final IconData icon;
  final String text;
  final bool error;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    final colors = _InventoryColors.of(context);
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: error ? colors.error : colors.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    style: AppTypography.subheadline.copyWith(
                      color: error ? colors.error : colors.secondary,
                    ),
                  ),
                ),
              ],
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: colors.teal,
                  minimumSize: const Size(44, 44),
                ),
                child: const Text('Coba lagi'),
              ),
          ],
        ),
      ),
    );
  }
}

class _InventoryEmpty extends StatelessWidget {
  const _InventoryEmpty({
    required this.failed,
    required this.firstRun,
    required this.onReset,
    required this.onRetry,
  });
  final bool failed, firstRun;
  final VoidCallback onReset, onRetry;
  @override
  Widget build(BuildContext context) {
    final colors = _InventoryColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        children: [
          InventoryIllustration(
            asset: firstRun
                ? InventoryIllustration.empty
                : InventoryIllustration.noResults,
            size: 144,
          ),
          const SizedBox(height: 16),
          Text(
            failed
                ? 'Inventaris belum dapat dimuat'
                : firstRun
                ? 'Persediaan dimulai di sini'
                : 'Barang tidak ditemukan',
            textAlign: TextAlign.center,
            style: AppTypography.title3.copyWith(color: colors.ink),
          ),
          const SizedBox(height: 8),
          Text(
            failed
                ? 'Periksa koneksi, lalu coba muat kembali.'
                : firstRun
                ? 'Tambahkan benih, nutrisi, atau perlengkapan pertama melalui tombol di bawah.'
                : 'Coba nama lain atau hapus filter untuk melihat semua barang.',
            textAlign: TextAlign.center,
            style: AppTypography.subheadline.copyWith(color: colors.secondary),
          ),
          if (!firstRun || failed)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextButton(
                onPressed: failed ? onRetry : onReset,
                style: TextButton.styleFrom(
                  foregroundColor: colors.teal,
                  minimumSize: const Size(44, 44),
                ),
                child: Text(failed ? 'Coba lagi' : 'Hapus filter'),
              ),
            ),
        ],
      ),
    );
  }
}

class _InventoryPlaceholder extends StatelessWidget {
  const _InventoryPlaceholder();
  @override
  Widget build(BuildContext context) {
    final colors = _InventoryColors.of(context);
    return ExcludeSemantics(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 80, height: 24, color: colors.mintSurface),
            const SizedBox(height: 12),
            Container(height: 64, color: colors.mintSurface),
            const SizedBox(height: 12),
            Container(width: 128, height: 20, color: colors.mintSurface),
          ],
        ),
      ),
    );
  }
}

class _InventoryColors {
  const _InventoryColors(this.dark);
  factory _InventoryColors.of(BuildContext context) =>
      _InventoryColors(Theme.of(context).brightness == Brightness.dark);
  final bool dark;
  Color get canvas => dark ? const Color(0xFF101D24) : AppColors.canvasWarm;
  Color get surface => dark ? const Color(0xFF1B2B34) : AppColors.cardSurface;
  Color get ink => dark ? const Color(0xFFF3F7F4) : AppColors.darkNavy;
  Color get secondary =>
      dark ? const Color(0xFFB3C1BB) : const Color(0xFF58665F);
  Color get teal => dark ? const Color(0xFF85DFCC) : const Color(0xFF0E756E);
  Color get onTeal => dark ? AppColors.darkNavy : Colors.white;
  Color get mintSurface =>
      dark ? const Color(0xFF223E37) : const Color(0xFFE9F3E7);
  Color get border => dark ? const Color(0xFF354C48) : const Color(0xFFDFE6DD);
  Color get controlBorder =>
      dark ? const Color(0xFF94A79B) : const Color(0xFF76857D);
  Color get error => dark ? const Color(0xFFFFB4AA) : const Color(0xFFB42318);
  Color get warning => dark ? const Color(0xFFFFC78F) : const Color(0xFF915016);
}
