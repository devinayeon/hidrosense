import 'package:flutter/material.dart';
import 'capsule_badge.dart';

class StockInfoRow extends StatelessWidget {
  final String stockValue;
  final String stockUnit;
  final String mainUnit;
  final Color unitTextColor;
  final Color badgeBgColor;
  final Color badgeTextColor;

  const StockInfoRow({
    super.key,
    required this.stockValue,
    required this.stockUnit,
    required this.mainUnit,
    this.unitTextColor = const Color.fromRGBO(57, 198, 195, 1),
    this.badgeBgColor = const Color.fromRGBO(220, 252, 92, 1),
    this.badgeTextColor = const Color.fromRGBO(20, 30, 45, 1),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Sisi Kiri: Stok Saat Ini
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Stok Saat Ini',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color.fromRGBO(107, 114, 128, 1),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  stockValue,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color.fromRGBO(17, 24, 39, 1),
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  stockUnit,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: unitTextColor,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ],
        ),

        // Sisi Kanan: Satuan Utama + CapsuleBadge
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Satuan Utama',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color.fromRGBO(107, 114, 128, 1),
              ),
            ),
            const SizedBox(height: 6),
            CapsuleBadge(
              label: mainUnit,
              textColor: badgeTextColor,
              backgroundColor: badgeBgColor,
              size: CapsuleSize.medium,
              fontWeight: FontWeight.w700,
            ),
          ],
        ),
      ],
    );
  }
}
