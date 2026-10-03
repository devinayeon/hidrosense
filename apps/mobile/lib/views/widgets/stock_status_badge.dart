import 'package:flutter/material.dart';

enum StockStatus { aman, menipis, habis }

class StockStatusBadge extends StatelessWidget {
  final StockStatus status;

  const StockStatusBadge({
    super.key,
    required this.status,
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
        statusColor = const Color.fromRGBO(239, 68, 68, 1); // Merah
        label = 'Stok Habis';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(237, 249, 248, 1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: statusColor,
          width: 1.0,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 11,
          color: statusColor,
          height: 1.0,
        ),
      ),
    );
  }
}