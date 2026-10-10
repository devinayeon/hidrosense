import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/panen_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../pages/laporan_panen_page.dart';
import '../pages/panen_form_page.dart';
import '../widgets/panen_card.dart';

class PanenBody extends ConsumerWidget {
  const PanenBody({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).user;
    if (user == null || !user.permissions.contains('panen:read')) {
      return const Center(child: Text('Akses panen tidak diizinkan.'));
    }
    final state = ref.watch(panenViewModelProvider);
    final filter = ref.watch(panenFilterCategoryProvider);
    final vm = ref.read(panenViewModelProvider.notifier);
    final batches = filter == PanenFilterCategory.completed
        ? []
        : state.upcoming;
    final records = filter == PanenFilterCategory.upcoming ? [] : state.records;
    return RefreshIndicator(
      onRefresh: vm.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in [
                (PanenFilterCategory.all, 'Semua Data'),
                (
                  PanenFilterCategory.upcoming,
                  'Mendatang (${state.upcoming.length})',
                ),
                (
                  PanenFilterCategory.completed,
                  'Selesai (${state.records.length})',
                ),
              ])
                ChoiceChip(
                  label: Text(entry.$2),
                  selected: filter == entry.$1,
                  onSelected: (_) =>
                      ref.read(panenFilterCategoryProvider.notifier).state =
                          entry.$1,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (state.loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Memuat data panen dan batch...'),
            ),
          if (state.error != null) ...[
            Text(
              state.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton(onPressed: vm.refresh, child: const Text('Coba lagi')),
          ],
          if (state.refreshWarning != null) Text(state.refreshWarning!),
          if (!vm.canReadBatches && filter != PanenFilterCategory.completed)
            const Text(
              'Akses budidaya diperlukan untuk melihat batch mendatang.',
            ),
          if (!state.loading &&
              state.error == null &&
              records.isEmpty &&
              batches.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Belum ada data panen. Catat hasil dari batch tanaman aktif.',
              ),
            ),
          for (final batch in batches)
            PanenCard(
              title: 'Batch #${batch.id}',
              subtitle:
                  'Meja #${batch.tableId} • ${batch.activePlants} tanaman aktif',
              result:
                  'Estimasi ${batch.estimatedHarvestDate ?? 'belum tersedia'}\nHSS ${batch.hss ?? 'belum tersedia'} • HST ${batch.hst ?? 'belum tersedia'}',
              completed: false,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PanenFormPage(transferId: batch.id),
                ),
              ),
            ),
          for (final record in records)
            PanenCard(
              title: 'Panen #${record.id}',
              subtitle:
                  '${record.date} • ${record.details.map((d) => d.tableCode).toSet().join(', ')}',
              result:
                  'Layak jual ${record.saleable.wire} kg • Total ${record.total?.wire ?? 'belum tercatat'}${record.total == null ? '' : ' kg'}',
              completed: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LaporanPanenPage(harvestId: record.id),
                ),
              ),
            ),
          if (vm.canWrite && vm.canReadBatches) ...[
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                vm.beginDraft();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PanenFormPage()),
                );
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Catat Hasil Panen Baru'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
