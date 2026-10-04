import 'package:flutter/material.dart';
import 'capsule_badge.dart';
import '../../models/inventory_item_model.dart'; // Sesuaikan relative path jika berbeda

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
        statusColor = const Color.fromRGBO(57, 198, 195, 1);
        bgColor = const Color.fromRGBO(237, 249, 248, 1);
        label = 'Stok Aman';
        break;
      case StockStatus.menipis:
        statusColor = const Color.fromRGBO(255, 154, 85, 1);
        bgColor = const Color.fromRGBO(255, 248, 243, 1);
        label = 'Stok Menipis';
        break;
      case StockStatus.habis:
        statusColor = const Color.fromRGBO(239, 68, 68, 1);
        bgColor = const Color.fromRGBO(254, 242, 242, 1);
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
