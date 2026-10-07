import 'package:flutter/material.dart';
import 'capsule_badge.dart';
import '../../models/inventory_item_model.dart'; // Sesuaikan relative path jika berbeda
import '../theme/app_theme.dart';

// enum StockStatus { aman, menipis, habis }

class StockStatusBadge extends StatelessWidget {
  final StockStatus status;
  final CapsuleSize size;

  const StockStatusBadge({
    super.key,
    required this.status,
    this.size = CapsuleSize.medium,
  });

  // Di file stock_status_badge.dart
  @override
  Widget build(BuildContext context) {
    Color statusColor;
    Color bgColor;
    String label;

    switch (status) {
      case StockStatus.aman:
        statusColor = AppColors.primaryDarkTeal;
        bgColor = const Color(0xFFEAF7F6);
        label = 'Stok Aman';
        break;
      case StockStatus.menipis:
        statusColor = AppColors.warningOrange;
        bgColor = AppColors.warningBg;
        label = 'Stok Menipis';
        break;
      case StockStatus.habis:
        statusColor = AppColors.dangerRed;
        bgColor = AppColors.dangerBg;
        label = 'Stok Habis';
        break;
    }

    return CapsuleBadge(
      label: label,
      textColor: statusColor,
      backgroundColor: bgColor,
      borderColor: statusColor,
      size: size,
      fontWeight: FontWeight.w700,
    );
  }
}
