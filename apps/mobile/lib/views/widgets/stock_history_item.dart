import 'package:flutter/material.dart';
import 'capsule_badge.dart';

class StockHistoryItem extends StatelessWidget {
  final String title;
  final String date;
  final String amountText;
  final bool isReduction; // true jika berkurang (-), false jika bertambah (+)

  const StockHistoryItem({
    super.key,
    required this.title,
    required this.date,
    required this.amountText,
    this.isReduction = false,
  });

  @override
  Widget build(BuildContext context) {
    // Warna badge berdasarkan jenis perubahan (kurang/tambah)
    final Color badgeBgColor = isReduction
        ? const Color.fromRGBO(255, 241, 236, 1) // Merah muda / Orange soft
        : const Color.fromRGBO(237, 249, 248, 1); // Tosca soft

    final Color badgeTextColor = isReduction
        ? const Color.fromRGBO(255, 138, 80, 1) // Orange / Merah
        : const Color.fromRGBO(57, 198, 195, 1); // Tosca

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Sisi Kiri: Judul Aktivitas & Tanggal
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color.fromRGBO(17, 24, 39, 1),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                date,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color.fromRGBO(156, 163, 175, 1),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Sisi Kanan: Capsule Badge Jumlah Stok
        CapsuleBadge(
          label: amountText,
          textColor: badgeTextColor,
          backgroundColor: badgeBgColor,
          size: CapsuleSize.medium,
          fontWeight: FontWeight.w700,
        ),
      ],
    );
  }
}
