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
      backgroundColor: const Color.fromRGBO(250, 250, 247, 1),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: Color.fromRGBO(23, 34, 49, 1),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Varietas: $variety',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color.fromRGBO(107, 114, 128, 1),
              ),
            ),
            const SizedBox(height: 20),
            BaseColCard(
              backgroundColor: Colors.white,
              borderColor: const Color.fromRGBO(243, 244, 246, 1),
              borderRadius: 20,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Progres Usia Semai',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color.fromRGBO(107, 114, 128, 1),
                        ),
                      ),
                      Text(
                        '$hssDays dari $totalHss Hari',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color.fromRGBO(23, 34, 49, 1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: progress),
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOutCubic,
                      builder: (context, animatedVal, _) =>
                          LinearProgressIndicator(
                            value: animatedVal,
                            minHeight: 10,
                            backgroundColor: const Color.fromRGBO(
                              229,
                              231,
                              235,
                              1,
                            ),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color.fromRGBO(57, 198, 195, 1),
                            ),
                          ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Rencana pindah tanam: HSS $totalHss',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: Color.fromRGBO(156, 163, 175, 1),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: BaseColCard(
                    backgroundColor: Colors.white,
                    borderColor: const Color.fromRGBO(243, 244, 246, 1),
                    borderRadius: 20,
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bibit Sehat',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: Color.fromRGBO(107, 114, 128, 1),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$count Bibit',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color.fromRGBO(23, 34, 49, 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BaseColCard(
                    backgroundColor: Colors.white,
                    borderColor: const Color.fromRGBO(243, 244, 246, 1),
                    borderRadius: 20,
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bibit Rusak',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: Color.fromRGBO(107, 114, 128, 1),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$damagedCount Bibit',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color.fromRGBO(23, 34, 49, 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (materials.isNotEmpty) ...[
              const Text(
                'BAHAN YANG DIGUNAKAN',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: Color.fromRGBO(107, 114, 128, 1),
                ),
              ),
              const SizedBox(height: 12),
              BaseColCard(
                backgroundColor: Colors.white,
                borderColor: const Color.fromRGBO(243, 244, 246, 1),
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
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
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: Color.fromRGBO(23, 34, 49, 1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 28),
            ],
            Row(
              children: [
                Expanded(
                  child: ColButton(
                    text: 'Kembali',
                    textColor: const Color.fromRGBO(57, 198, 195, 1),
                    backgroundColor: Colors.white,
                    borderColor: const Color.fromRGBO(57, 198, 195, 1),
                    height: 52,
                    borderRadius: 25,
                    onPressed: () {
                      HapticFeedback.heavyImpact();
                      Navigator.pop(context);
                    },
                  ),
                ),
                if (sowingRecord?.status == 'aktif' &&
                    sowingRecord?.isReadyToMove == true &&
                    !_transferred) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ColButton(
                      text: 'Pindahkan ke Meja',
                      textColor: AppColors.darkNavy,
                      backgroundColor: AppColors.accentLime,
                      borderColor: AppColors.accentLime,
                      height: 52,
                      borderRadius: 25,
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
