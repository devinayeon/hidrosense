import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/table_record.dart';
import '../../data/models/transfer_record.dart';
import '../../viewmodels/damage_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../pages/catat_kerusakan_page.dart';
import '../theme/app_theme.dart';
import '../widgets/transfer_note_dialog.dart';

class DetailTanamanMejaBody extends ConsumerWidget {
  const DetailTanamanMejaBody({super.key, required this.table});
  final TableRecord table;

  Future<void> _editTransferNote(
    BuildContext context,
    DamageViewModel notifier,
    TransferRecord transfer,
  ) async {
    if (notifier.current.submitting || !notifier.mounted) return;
    notifier.beginDraft();
    await showDialog<void>(
      context: context,
      builder: (_) => TransferNoteDialog(
        notifier: notifier,
        transfer: transfer,
        onSaved: (warning) {
          if (context.mounted && warning != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(warning)));
          }
        },
      ),
    );
  }

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
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
              ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.card),
                side: const BorderSide(color: AppColors.borderLight),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            transfer.label,
                            style: AppTypography.headline.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (permissions.contains('budidaya:write'))
                          IconButton(
                            icon: const Icon(Icons.edit_note_rounded, size: 22),
                            tooltip: 'Ubah Catatan Batch',
                            color: AppColors.textPrimary,
                            onPressed: () =>
                                _editTransferNote(context, notifier, transfer),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${transfer.activePlants} tanaman aktif / ${transfer.plantCount} dipindahkan',
                      style: AppTypography.tabular(AppTypography.subheadline)
                          .copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentMintSoft,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            'HSS: ${transfer.hss == null ? 'belum tersedia' : '${transfer.hss} Hari'}',
                            style: AppTypography.tabular(AppTypography.caption1)
                                .copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryMint.withValues(
                              alpha: 0.15,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            'HST: ${transfer.hst == null ? 'belum tersedia' : '${transfer.hst} Hari'}',
                            style: AppTypography.tabular(AppTypography.caption1)
                                .copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                          ),
                        ),
                        if (transfer.estimatedHarvestDate != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.cardSurface,
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            child: Text(
                              'Estimasi panen: ${transfer.estimatedHarvestDate} (${transfer.remainingHarvestDays == null ? 'belum tersedia' : '${transfer.remainingHarvestDays} hr'})',
                              style: AppTypography.tabular(
                                AppTypography.caption1,
                              ).copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                      ],
                    ),
                    if (transfer.note != null && transfer.note!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Catatan: ${transfer.note}',
                        style: AppTypography.tabular(AppTypography.caption1)
                            .copyWith(
                              fontStyle: FontStyle.italic,
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: AppColors.borderLight),
                    const SizedBox(height: 10),
                    Text(
                      'Laporan Kerusakan Tersimpan',
                      style: AppTypography.tabular(AppTypography.caption1)
                          .copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 6),
                    if ((state.reports[transfer.id] ?? []).isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'Belum ada laporan kerusakan.',
                          style: AppTypography.tabular(
                            AppTypography.caption1,
                          ).copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                    for (final report in state.reports[transfer.id] ?? [])
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(AppRadius.input),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${report.date} • ${report.plantCount} tanaman • ${report.category}',
                                    style:
                                        AppTypography.tabular(
                                          AppTypography.caption1,
                                        ).copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                  ),
                                  if (report.note != null &&
                                      report.note!.isNotEmpty)
                                    Text(
                                      report.note!,
                                      style:
                                          AppTypography.tabular(
                                            AppTypography.caption1,
                                          ).copyWith(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                ],
                              ),
                            ),
                            if (permissions.contains('budidaya:write'))
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                color: AppColors.textPrimary,
                                tooltip: 'Ubah Laporan',
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<bool>(
                                    builder: (_) => CatatKerusakanPage(
                                      table: table,
                                      initialTransfer: transfer,
                                      damageRecordToEdit: report,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),
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
