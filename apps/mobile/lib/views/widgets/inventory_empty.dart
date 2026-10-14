import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'inventory_colors.dart';
import 'inventory_illustration.dart';

/// Tampilan kosong / empty state untuk halaman inventaris.
/// Menangani 3 kondisi: gagal memuat, pertama kali buka, dan tidak ada hasil pencarian.
class InventoryEmpty extends StatelessWidget {
  const InventoryEmpty({
    super.key,
    required this.failed,
    required this.firstRun,
    required this.onReset,
    required this.onRetry,
  });

  /// True jika terjadi error dan tidak ada data sama sekali.
  final bool failed;

  /// True jika belum pernah ada data (inventaris kosong).
  final bool firstRun;

  /// Callback untuk menghapus filter pencarian.
  final VoidCallback onReset;

  /// Callback untuk mencoba memuat ulang data.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = InventoryColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        children: [
          InventoryIllustration(
            asset: firstRun
                ? InventoryIllustration.empty
                : InventoryIllustration.noResults,
            size: 144,
          ),
          const SizedBox(height: 16),
          Text(
            failed
                ? 'Inventaris belum dapat dimuat'
                : firstRun
                ? 'Persediaan dimulai di sini'
                : 'Barang tidak ditemukan',
            textAlign: TextAlign.center,
            style: AppTypography.title3.copyWith(color: colors.ink),
          ),
          const SizedBox(height: 8),
          Text(
            failed
                ? 'Periksa koneksi, lalu coba muat kembali.'
                : firstRun
                ? 'Tambahkan benih, nutrisi, atau perlengkapan pertama melalui tombol di bawah.'
                : 'Coba nama lain atau hapus filter untuk melihat semua barang.',
            textAlign: TextAlign.center,
            style: AppTypography.subheadline.copyWith(
              color: colors.secondary,
            ),
          ),
          if (!firstRun || failed)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextButton(
                onPressed: failed ? onRetry : onReset,
                style: TextButton.styleFrom(
                  foregroundColor: colors.teal,
                  minimumSize: const Size(44, 44),
                ),
                child: Text(failed ? 'Coba lagi' : 'Hapus filter'),
              ),
            ),
        ],
      ),
    );
  }
}
