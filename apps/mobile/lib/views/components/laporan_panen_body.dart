// lib/views/components/laporan_panen_body.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/panen_model.dart';
import '../pages/panen_form_page.dart';
import '../theme/app_theme.dart';
import '../widgets/base_col_card.dart';
import '../widgets/col_button.dart';
import '../widgets/row_info_card_md.dart';

class LaporanPanenBody extends StatelessWidget {
  final PanenItem item;

  const LaporanPanenBody({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
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
            // 1. Title Header Laporan Panen
            Text(
              'Laporan Panen - ${item.batchName}',
              style: AppTypography.title2.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Selesai diproses pada ${item.processedDate}',
              style: AppTypography.subheadline.copyWith(
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // 2. Row Info Cards (Total Berat Hasil & Rasio Layak/Reject)
            Row(
              children: [
                Expanded(
                  child: BaseColCard(
                    backgroundColor: Colors.white,
                    borderColor: AppColors.borderLight,
                    borderRadius: AppRadius.card,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Berat Hasil',
                          style: AppTypography.caption1.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          item.totalWeight,
                          style: AppTypography.title2.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Target: ${item.targetWeight}',
                          style: AppTypography.caption2.copyWith(
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
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
                    borderRadius: AppRadius.card,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rasio Layak/Reject',
                          style: AppTypography.caption1.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${item.layakPercent} / ${item.rejectPercent}',
                          style: AppTypography.title2.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.successGreen,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Reject: ${item.rejectWeight}',
                          style: AppTypography.caption2.copyWith(
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // 3. Section Informasi Produksi & Penjualan
            Text(
              'INFORMASI PRODUKSI & PENJUALAN',
              style: AppTypography.caption1.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            RowInfoCardMd(
              backgroundColor: Colors.white,
              borderColor: AppColors.borderLight,
              borderRadius: AppRadius.modal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              child: Column(
                children: [
                  _buildDetailRow('Asal Meja Tanam:', item.asalMejaTanam),
                  const SizedBox(height: AppSpacing.sm),
                  _buildDetailRow('Varietas Tanaman:', item.varietas),
                  const SizedBox(height: AppSpacing.sm),
                  _buildDetailRow('Lama Budidaya (HSS):', item.lamaBudidaya),
                  const SizedBox(height: AppSpacing.sm),
                  _buildDetailRow(
                    'Grade Kualitas Utama:',
                    item.gradeKualitas,
                    valueColor: AppColors.successGreen,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // 4. Action Buttons (Edit Laporan & Ekspor ke PDF) Apple HIG 52pt
            Row(
              children: [
                Expanded(
                  child: ColButton(
                    text: 'Edit Laporan',
                    textColor: AppColors.primaryMint,
                    borderColor: AppColors.primaryMint,
                    backgroundColor: Colors.white,
                    height: 52,
                    borderRadius: AppRadius.pill,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PanenFormPage(itemToEdit: item),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ColButton(
                    text: 'Ekspor ke PDF',
                    textColor: Colors.white,
                    borderColor: AppColors.primaryMint,
                    backgroundColor: AppColors.primaryMint,
                    height: 52,
                    borderRadius: AppRadius.pill,
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      // Action Ekspor ke PDF
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.subheadline.copyWith(
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppTypography.subheadline.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
