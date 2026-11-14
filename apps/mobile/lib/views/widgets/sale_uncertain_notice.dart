import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Penanda hasil belum pasti: warna peringatan yang sama dengan label stok.
class SaleUncertainNotice extends StatelessWidget {
  const SaleUncertainNotice({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.warningBg,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.warningOrange),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.sync_problem_outlined,
              size: 20,
              color: AppColors.textPrimary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                message,
                style: AppTypography.footnote.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Jalan keluar bila kiriman ulang terus gagal. Pengguna diminta memeriksa
/// daftar dulu, karena isian yang dibuang lalu dicatat lagi bisa menjadi ganda.
Future<bool> confirmSaleDiscard(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: const Text('Buang isian ini?'),
      content: const Text(
        'Periksa daftar penjualan dulu. Bila penjualan ini sudah ada, isian '
        'boleh dibuang. Bila belum ada, catat lagi setelah isian dibuang.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog, false),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialog, true),
          child: const Text('Ya, Buang'),
        ),
      ],
    ),
  );
  return confirmed == true;
}
