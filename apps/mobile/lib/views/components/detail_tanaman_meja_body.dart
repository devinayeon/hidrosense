import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/table_record.dart';
import '../../viewmodels/damage_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../pages/catat_kerusakan_page.dart';
import '../theme/app_theme.dart';

class DetailTanamanMejaBody extends ConsumerWidget {
  const DetailTanamanMejaBody({super.key, required this.table});
  final TableRecord table;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions =
        ref.watch(sessionProvider).user?.permissions ?? const <String>[];
    if (!permissions.contains('budidaya:read')) {
      return const Center(child: Text('Akses batch tanaman tidak diizinkan.'));
    }
    final state = ref.watch(damageProvider(table.id));
    final notifier = ref.read(damageProvider(table.id).notifier);
    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (state.loading) const LinearProgressIndicator(),
          if (state.error != null) ...[
            Text(
              state.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton(
              onPressed: notifier.refresh,
              child: const Text('Coba lagi'),
            ),
          ],
          if (state.refreshWarning != null) Text(state.refreshWarning!),
          if (!state.loading && state.transfers.isEmpty && state.error == null)
            const Text('Belum ada batch pemindahan pada meja ini.'),
          for (final transfer in state.transfers)
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      transfer.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${transfer.activePlants} tanaman aktif / ${transfer.plantCount} dipindahkan',
                    ),
                    const SizedBox(height: 12),
                    const Text('Laporan kerusakan tersimpan'),
                    if ((state.reports[transfer.id] ?? []).isEmpty)
                      const Text('Belum ada laporan kerusakan.'),
                    for (final report in state.reports[transfer.id] ?? [])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '${report.date} • ${report.plantCount} tanaman • ${report.category}'
                          '${report.note == null ? '' : '\n${report.note}'}',
                        ),
                      ),
                    if (permissions.contains('budidaya:write'))
                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(44, 48),
                          backgroundColor: AppColors.darkNavy,
                          foregroundColor: AppColors.accentLime,
                        ),
                        onPressed:
                            state.loading ||
                                state.submitting ||
                                transfer.activePlants == 0
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute<bool>(
                                  builder: (_) => CatatKerusakanPage(
                                    table: table,
                                    initialTransfer: transfer,
                                  ),
                                ),
                              ),
                        child: const Text('Catat Kerusakan'),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
