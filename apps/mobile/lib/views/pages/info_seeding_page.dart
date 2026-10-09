import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/nursery_record.dart';
import '../../models/seeding_batch_model.dart';
import '../../viewmodels/connected_nursery_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../components/header.dart';
import '../theme/app_theme.dart';
import '../widgets/base_col_card.dart';
import '../widgets/col_button.dart';
import '../widgets/seedling_transfer_sheet.dart';
import 'seeding_form_page.dart';

class InfoSeedingPage extends ConsumerStatefulWidget {
  final SeedingBatch? seedingItem;
  final SowingRecord? sowingRecord;

  const InfoSeedingPage({super.key, this.seedingItem, this.sowingRecord})
    : assert(seedingItem != null || sowingRecord != null);

  @override
  ConsumerState<InfoSeedingPage> createState() => _InfoSeedingPageState();
}

class _InfoSeedingPageState extends ConsumerState<InfoSeedingPage> {
  bool _transferred = false;

  @override
  Widget build(BuildContext context) {
    final original = widget.sowingRecord;
    SowingRecord? sowingRecord;
    var canWrite = false;
    if (original != null) {
      final user = ref.watch(sessionProvider).user;
      if (user == null || !user.permissions.contains('penyemaian:read')) {
        return const Scaffold(
          body: SafeArea(
            child: Center(child: Text('Anda tidak memiliki akses penyemaian.')),
          ),
        );
      }
      canWrite = user.permissions.contains('penyemaian:write');
      final detail = ref.watch(sowingDetailProvider(original.id));
      if (detail.isLoading) {
        return const Scaffold(
          appBar: Header(titleText: 'Detail Penyemaian', showBackButton: true),
          body: Center(child: CircularProgressIndicator()),
        );
      }
      if (detail.hasError) {
        return Scaffold(
          appBar: const Header(
            titleText: 'Detail Penyemaian',
            showBackButton: true,
          ),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(serviceError(detail.error!)),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(sowingDetailProvider(original.id)),
                  child: const Text('Muat ulang penyemaian'),
                ),
              ],
            ),
          ),
        );
      }
      sowingRecord = detail.requireValue;
    }
    final seedingItem = widget.seedingItem;
    final title = sowingRecord != null
        ? sowingRecord.batchName
        : 'Batch Penyemaian #${seedingItem!.batchNumber}';
    final hssDays = sowingRecord != null
        ? (sowingRecord.ageDays ?? 0)
        : seedingItem!.hss;
    final totalHss = sowingRecord == null ? seedingItem!.totalHss : 15;
    final progress = (hssDays / totalHss).clamp(0.0, 1.0);
    final count = sowingRecord != null
        ? sowingRecord.remainingSeedCount
        : seedingItem!.healthyCount;
    final damagedCount = seedingItem?.damagedCount;
    final materials = sowingRecord != null
        ? sowingRecord.materials
              .map((m) => '${m.inventoryId}: ${m.amount} ${m.unit}')
              .toList()
        : (seedingItem?.materials ?? const <String>[]);

    return Scaffold(
      appBar: Header(
        titleText: 'Detail Penyemaian',
        showBackButton: true,
        toolbarHeight:
            kToolbarHeight * MediaQuery.textScalerOf(context).scale(1),
        titleMaxLines: 2,
      ),
      backgroundColor: AppColors.canvasWarm,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.title2.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      if (seedingItem != null)
                        Text(
                          'Varietas: ${seedingItem.variety}',
                          style: AppTypography.subheadline.copyWith(
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                if (canWrite && sowingRecord?.status == 'aktif')
                  InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              SeedingFormPage(sowingRecord: sowingRecord),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryMint.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: AppColors.primaryMint),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.edit_outlined,
                            size: 14,
                            color: AppColors.textPrimary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Ubah',
                            style: AppTypography.caption1.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            BaseColCard(
              backgroundColor: Colors.white,
              borderColor: AppColors.borderLight,
              borderRadius: AppRadius.modal,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Progres Usia Semai',
                          style: AppTypography.caption1.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          '$hssDays dari $totalHss Hari',
                          textAlign: TextAlign.end,
                          style: AppTypography.subheadline.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.badge),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: progress),
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOutCubic,
                      builder: (context, animatedVal, _) =>
                          LinearProgressIndicator(
                            value: animatedVal,
                            minHeight: 10,
                            backgroundColor: AppColors.borderLight,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primaryMint,
                            ),
                          ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Rencana pindah tanam: HSS $totalHss',
                    style: AppTypography.caption1.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: BaseColCard(
                    backgroundColor: Colors.white,
                    borderColor: AppColors.borderLight,
                    borderRadius: AppRadius.modal,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bibit Tersisa',
                          style: AppTypography.caption1.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '$count Bibit',
                          style: AppTypography.title2.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (damagedCount != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: BaseColCard(
                      backgroundColor: Colors.white,
                      borderColor: AppColors.borderLight,
                      borderRadius: AppRadius.modal,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bibit Rusak',
                            style: AppTypography.caption1.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            '$damagedCount Bibit',
                            style: AppTypography.title2.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            if (sowingRecord?.note case final String note) ...[
              Text('Catatan Penyemaian', style: AppTypography.headline),
              Text(note, style: AppTypography.body),
              const SizedBox(height: AppSpacing.md),
            ],
            if (materials.isNotEmpty) ...[
              Text(
                'BAHAN YANG DIGUNAKAN',
                style: AppTypography.caption1.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              BaseColCard(
                backgroundColor: Colors.white,
                borderColor: AppColors.borderLight,
                borderRadius: AppRadius.modal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: materials.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          const Text(
                            '• ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Expanded(
                            child: Text(
                              item,
                              style: AppTypography.subheadline.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
            Row(
              children: [
                Expanded(
                  child: ColButton(
                    text: 'Kembali',
                    textColor: AppColors.textPrimary,
                    backgroundColor: Colors.white,
                    borderColor: AppColors.primaryMint,
                    height: 52 * MediaQuery.textScalerOf(context).scale(1),
                    borderRadius: AppRadius.pill,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                  ),
                ),
                if (canWrite &&
                    sowingRecord != null &&
                    sowingRecord.status == 'aktif' &&
                    !sowingRecord.isReadyToMove) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ColButton(
                      text: 'Ubah Data',
                      textColor: AppColors.accentLime,
                      backgroundColor: AppColors.darkNavy,
                      borderColor: AppColors.darkNavy,
                      height: 52 * MediaQuery.textScalerOf(context).scale(1),
                      borderRadius: AppRadius.pill,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SeedingFormPage(sowingRecord: sowingRecord),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                if (canWrite &&
                    sowingRecord?.status == 'aktif' &&
                    sowingRecord?.isReadyToMove == true &&
                    (sowingRecord?.remainingSeedCount ?? 0) > 0 &&
                    !_transferred) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ColButton(
                      text: 'Pindahkan ke Meja',
                      textColor: AppColors.darkNavy,
                      backgroundColor: AppColors.accentLime,
                      borderColor: AppColors.accentLime,
                      height: 52 * MediaQuery.textScalerOf(context).scale(1),
                      borderRadius: AppRadius.pill,
                      fontSize: 13.5,
                      onPressed: () {
                        showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          isDismissible: false,
                          enableDrag: false,
                          builder: (_) => SeedlingTransferSheet(
                            sowingRecord: sowingRecord!,
                            onTransferred: () {
                              if (mounted) setState(() => _transferred = true);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
