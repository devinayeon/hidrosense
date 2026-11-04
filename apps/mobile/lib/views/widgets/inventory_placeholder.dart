import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'inventory_colors.dart';

/// Placeholder loading untuk kartu inventaris saat data pertama kali dimuat.
/// Dikecualikan dari semantics agar screen reader tidak membacanya.
class InventoryPlaceholder extends StatelessWidget {
  const InventoryPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = InventoryColors.of(context);
    return ExcludeSemantics(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 80, height: 24, color: colors.mintSurface),
            const SizedBox(height: 12),
            Container(height: 64, color: colors.mintSurface),
            const SizedBox(height: 12),
            Container(width: 128, height: 20, color: colors.mintSurface),
          ],
        ),
      ),
    );
  }
}
