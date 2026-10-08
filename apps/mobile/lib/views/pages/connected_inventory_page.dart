import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/inventory_record.dart';
import '../../viewmodels/connected_inventory_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../pages/add_form_inventaris_page.dart';
import '../theme/app_theme.dart';

class ConnectedInventoryPage extends ConsumerStatefulWidget {
  const ConnectedInventoryPage({super.key});

  @override
  ConsumerState<ConnectedInventoryPage> createState() =>
      _ConnectedInventoryPageState();
}

class _ConnectedInventoryPageState
    extends ConsumerState<ConnectedInventoryPage> {
  String _search = '';
  String? _category;

  void _showDetail(InventoryRecord item) {
    showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: Text(item.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Jenis: ${item.category}'),
              const SizedBox(height: 12),
              _InventoryBalance(item: item, showLabel: true),
              const SizedBox(height: 12),
              Text(
                item.minimum == null
                    ? 'Stok minimum belum ditetapkan.'
                    : 'Stok minimum: ${item.minimum} ${item.unit}',
              ),
              const SizedBox(height: 12),
              _StockStatus(item: item),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => AddFormInventarisPage(initialRecord: item),
                ),
              );
            },
            child: const Text('Ubah'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(connectedInventoryProvider);
    final session = ref.watch(sessionProvider);
    final refresh = ref.read(connectedInventoryProvider.notifier).refresh;
    final active = state.records.where((item) => item.active).toList();
    final categories = active.map((item) => item.category).toSet().toList()
      ..sort();
    final selectedCategory = categories.contains(_category) ? _category : null;
    final items = active.where((item) {
      return (selectedCategory == null || item.category == selectedCategory) &&
          item.name.toLowerCase().contains(_search.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.canvasWarm,
      appBar: AppBar(
        title: const Text('Inventaris'),
        backgroundColor: AppColors.canvasWarm,
        actions: [
          IconButton(
            tooltip: 'Perbarui inventaris',
            onPressed: state.loading ? null : refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Keluar',
            onPressed: session.busy
                ? null
                : ref.read(sessionProvider.notifier).logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (session.user != null)
              Text(
                '${session.user!.name} · '
                '${session.user!.role == 'petani' ? 'Petani' : 'Pegawai'}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            const SizedBox(height: 4),
            const Text('Daftar barang dan saldo stok'),
            const SizedBox(height: 16),
            if (state.cached)
              const _Notice(
                icon: Icons.offline_pin_outlined,
                text: 'Menampilkan salinan lokal. Saldo mungkin sudah berubah.',
              ),
            if (state.fetchedAt != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Terakhir diperbarui: '
                  '${DateFormat('dd/MM/yyyy HH:mm').format(state.fetchedAt!.toLocal())}',
                ),
              ),
            if (state.error != null)
              _Notice(icon: Icons.info_outline, text: state.error!),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Cari barang',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _search = value.trim()),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('Semua'),
                      selected: selectedCategory == null,
                      onSelected: (_) => setState(() => _category = null),
                    ),
                  ),
                  for (final category in categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: selectedCategory == category,
                        onSelected: (_) => setState(() => _category = category),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (state.loading) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
            ],
            if (items.isEmpty && !state.loading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  state.error != null && active.isEmpty
                      ? 'Data inventaris belum dapat ditampilkan.'
                      : active.isEmpty
                      ? 'Belum ada barang inventaris aktif.'
                      : 'Tidak ada barang yang cocok.',
                  textAlign: TextAlign.center,
                ),
              ),
            for (final item in items)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const Icon(
                    Icons.inventory_2_outlined,
                    color: AppColors.primaryDarkTeal,
                  ),
                  title: Text(item.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(item.category, style: AppTypography.subheadline),
                      const SizedBox(height: AppSpacing.xxs),
                      _InventoryBalance(item: item),
                      const SizedBox(height: AppSpacing.xs),
                      _StockStatus(item: item),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showDetail(item),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => const AddFormInventarisPage(),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Barang'),
        backgroundColor: AppColors.primaryDarkTeal,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _InventoryBalance extends StatelessWidget {
  const _InventoryBalance({required this.item, this.showLabel = false});

  final InventoryRecord item;
  final bool showLabel;

  @override
  Widget build(BuildContext context) => Text(
    '${showLabel ? 'Saldo: ' : ''}${item.balance} ${item.unit}',
    style: AppTypography.tabular(AppTypography.headline),
  );
}

class _StockStatus extends StatelessWidget {
  const _StockStatus({required this.item});

  final InventoryRecord item;

  @override
  Widget build(BuildContext context) {
    if (item.isOutOfStock) {
      return const Text('Stok habis', style: AppTypography.footnote);
    }
    if (!item.isLow) {
      return Text(
        item.minimum == null ? 'Stok tersedia' : 'Stok mencukupi',
        style: AppTypography.footnote,
      );
    }
    return Semantics(
      container: true,
      label: 'Stok Menipis',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: AppColors.warningBg,
          border: Border.all(color: AppColors.warningOrange),
          borderRadius: BorderRadius.circular(AppRadius.badge),
        ),
        child: Text(
          'Stok Menipis',
          style: AppTypography.caption1.copyWith(color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    ),
  );
}
