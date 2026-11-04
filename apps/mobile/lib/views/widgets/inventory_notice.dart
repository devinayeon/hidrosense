import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'inventory_colors.dart';

/// Banner notifikasi ringan untuk kondisi cached atau error pada inventaris.
/// Mendukung tombol "Coba lagi" bila [onRetry] diberikan.
class InventoryNotice extends StatelessWidget {
  const InventoryNotice({
    super.key,
    required this.icon,
    required this.text,
    this.error = false,
    this.onRetry,
  });

  final IconData icon;
  final String text;
  final bool error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = InventoryColors.of(context);
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: error ? colors.error : colors.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    style: AppTypography.subheadline.copyWith(
                      color: error ? colors.error : colors.secondary,
                    ),
                  ),
                ),
              ],
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: colors.teal,
                  minimumSize: const Size(44, 44),
                ),
                child: const Text('Coba lagi'),
              ),
          ],
        ),
      ),
    );
  }
}
