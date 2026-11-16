import 'package:flutter/material.dart';

import '../../core/formatting.dart';
import '../../models/penjualan_model.dart';
import '../theme/app_theme.dart';

class SaleMultiBatchNotice extends StatelessWidget {
  const SaleMultiBatchNotice({super.key, required this.item});

  final PenjualanItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.accentMintSoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.layers_outlined,
            size: 20,
            color: AppColors.primaryDarkTeal,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transaksi ${item.details.length} batch panen',
                  style: AppTypography.subheadline.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Rincian batch, berat, dan harga tidak diubah. '
                  'Hanya data transaksi di atas yang diperbarui.',
                  style: AppTypography.footnote.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total ${item.kuantitas} · ${formatRupiah(item.totalHarga)}',
                  style: AppTypography.footnote.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
