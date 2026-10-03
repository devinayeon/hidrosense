import 'package:flutter/material.dart';
import 'capsule_badge.dart';

enum StockStatus { aman, menipis, habis }

class StockStatusBadge extends StatelessWidget {
  final StockStatus status;
  final CapsuleSize size;

  const StockStatusBadge({
    super.key,
    required this.status,
    this.size = CapsuleSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String label;

    switch (status) {
      case StockStatus.aman:
        statusColor = const Color.fromRGBO(57, 198, 195, 1);
        label = 'Stok Aman';
        break;
      case StockStatus.menipis:
        statusColor = const Color.fromRGBO(255, 154, 85, 1);
        label = 'Stok Menipis';
        break;
      case StockStatus.habis:
        statusColor = const Color.fromRGBO(239, 68, 68, 1);
        label = 'Stok Habis';
        break;
    }

    return CapsuleBadge(
      label: label,
      textColor: statusColor,
      backgroundColor: const Color.fromRGBO(237, 249, 248, 1),
      borderColor: statusColor,
      size: size,
      fontWeight: FontWeight.w700,
    );
  }
}
