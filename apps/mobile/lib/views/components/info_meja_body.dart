import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/connected_table_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../pages/detail_tanaman_meja_page.dart';
import '../../data/models/table_record.dart';
import '../../models/meja_nft_model.dart';
import '../pages/form_meja_nft_page.dart';
import '../theme/app_theme.dart';
import '../widgets/row_info_card_md.dart';
import '../widgets/row_button.dart';
import '../widgets/fluid_capacity_meter.dart';

class InfoMejaBody extends ConsumerWidget {
  final TableRecord? tableRecord;
  final MejaNft? mejaItem;

  const InfoMejaBody({super.key, this.tableRecord, this.mejaItem})
    : assert(tableRecord != null || mejaItem != null);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions =
        ref.watch(sessionProvider).user?.permissions ?? const <String>[];
    final records = this.tableRecord == null
        ? const <TableRecord>[]
        : ref.watch(connectedTableProvider).records;
    final current = records.where((r) => r.id == this.tableRecord?.id);
    final tableRecord = current.isEmpty ? this.tableRecord : current.first;
    final title = tableRecord?.displayName ?? mejaItem!.name;
    final totalCapacity = tableRecord?.holeCount ?? mejaItem!.capacityTotal;
    final activePlants = tableRecord?.activePlants ?? mejaItem!.capacityUsed;
    final isMaintenance =
        tableRecord?.isMaintenance ??
        (mejaItem!.status == MejaStatus.perawatan);
    final statusLabel =
        tableRecord?.statusLabel ?? (isMaintenance ? 'Perawatan' : 'Aktif');
    final notes =
        tableRecord?.notes ??
        mejaItem?.notes ??
        'Tidak ada catatan spesifikasi khusus.';

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.canvasWarm,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTypography.title2.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Sistem NFT • Status: $statusLabel',
              style: AppTypography.subheadline.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            RowInfoCardMd(
              backgroundColor: AppColors.cardSurface,
              borderColor: AppColors.borderSubtle,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: FluidCapacityMeter(
                activePlants: activePlants,
                totalCapacity: totalCapacity,
                height: 12.0,
                showLabel: true,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'CATATAN & SPESIFIKASI',
              style: AppTypography.caption1.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            RowInfoCardMd(
              backgroundColor: AppColors.cardSurface,
              borderColor: AppColors.borderSubtle,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                notes,
                style: AppTypography.subheadline.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (tableRecord != null &&
                permissions.contains('budidaya:read')) ...[
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => DetailTanamanMejaPage(table: tableRecord),
                  ),
                ),
                child: const Text('Batch & Laporan Kerusakan'),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (permissions.contains('budidaya:write'))
              RowButton(
                label: 'Edit Pengaturan Meja',
                backgroundColor: AppColors.darkNavy,
                textColor: AppColors.accentLime,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FormMejaNftPage(
                        tableRecord: tableRecord,
                        mejaItem: mejaItem,
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
