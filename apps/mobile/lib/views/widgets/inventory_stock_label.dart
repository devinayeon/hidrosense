import 'package:flutter/material.dart';
import '../../data/models/inventory_record.dart';
import '../theme/app_theme.dart';
import 'inventory_colors.dart';

/// Badge status stok untuk sebuah item inventaris.
/// Menampilkan label berwarna sesuai kondisi stok (habis, menipis, mencukupi).
class InventoryStockLabel extends StatelessWidget {
  const InventoryStockLabel({super.key, required this.item});

  final InventoryRecord item;

  @override
  Widget build(BuildContext context) {
    final colors = InventoryColors.of(context);
    final label = item.isOutOfStock
        ? 'Stok habis'
        : item.isLow
        ? 'Stok menipis'
        : item.minimum == null
        ? 'Stok tersedia'
        : 'Stok mencukupi';
    final color = item.isOutOfStock
        ? colors.error
        : item.isLow
        ? colors.warning
        : colors.teal;
    return Text(
      label,
      style: AppTypography.footnote.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
