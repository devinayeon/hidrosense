import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/nursery_record.dart';
import '../../models/seeding_batch_model.dart';
import '../components/header.dart';
import '../theme/app_theme.dart';
import '../widgets/base_col_card.dart';
import '../widgets/col_button.dart';
import '../widgets/seedling_transfer_sheet.dart';

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
    final sowingRecord = widget.sowingRecord;
    final seedingItem = widget.seedingItem;
    final title = sowingRecord != null
        ? sowingRecord.batchName
        : 'Batch Penyemaian #${seedingItem!.batchNumber}';
    final variety = sowingRecord != null
        ? 'Varietas Selada'
        : seedingItem!.variety;
    final hssDays = sowingRecord != null
        ? (sowingRecord.ageDays ?? 0)
        : seedingItem!.hss;
    final totalHss = sowingRecord == null ? seedingItem!.totalHss : 15;
    final progress = (hssDays / totalHss).clamp(0.0, 1.0);
    final count = sowingRecord != null
        ? sowingRecord.seedCount
        : seedingItem!.healthyCount;
    final damagedCount = seedingItem?.damagedCount ?? 0;
    final materials = sowingRecord != null
        ? sowingRecord.materials
              .map((m) => '${m.inventoryId}: ${m.amount} ${m.unit}')
              .toList()
        : (seedingItem?.materials ?? const <String>[]);

    return Scaffold(
      appBar: const Header(
        titleText: 'Detail Penyemaian',
        showBackButton: true,
      ),
      backgroundColor: AppColors.canvasWarm,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
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
            Text(
              'Varietas: $variety',
              style: AppTypography.subheadline.copyWith(
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
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
                      Text(
                        'Progres Usia Semai',
                        style: AppTypography.caption1.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '$hssDays dari $totalHss Hari',
                        style: AppTypography.subheadline.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
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
                      color: AppColors.textTertiary,
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
                          'Bibit Sehat',
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
            ),
            const SizedBox(height: AppSpacing.xl),
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
                    textColor: AppColors.primaryMint,
                    backgroundColor: Colors.white,
                    borderColor: AppColors.primaryMint,
                    height: 52,
                    borderRadius: AppRadius.pill,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                  ),
                ),
                if (sowingRecord?.status == 'aktif' &&
                    sowingRecord?.isReadyToMove == true &&
                    !_transferred) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ColButton(
                      text: 'Pindahkan ke Meja',
                      textColor: AppColors.darkNavy,
                      backgroundColor: AppColors.accentLime,
                      borderColor: AppColors.accentLime,
                      height: 52,
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
