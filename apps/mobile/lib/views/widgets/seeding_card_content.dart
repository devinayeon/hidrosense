import 'package:flutter/material.dart';
import 'capsule_badge.dart';

class SeedingCardContent extends StatelessWidget {
  final String batchName;
  final String statusLabel;
  final Color statusTextColor;
  final Color statusBgColor;
  final Color statusBorderColor;
  final String variety;
  final String dateText;
  final String seedCountText;
  final String hssText;
  final String? note;

  const SeedingCardContent({
    super.key,
    required this.batchName,
    required this.statusLabel,
    required this.statusTextColor,
    required this.statusBgColor,
    required this.statusBorderColor,
    required this.variety,
    required this.dateText,
    required this.seedCountText,
    required this.hssText,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Baris Atas: Judul Batch dan Badge Status
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              // Tambahkan Expanded
              child: Text(
                batchName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(width: 8), // Berikan jarak aman
            CapsuleBadge(
              label: statusLabel,
              textColor: statusTextColor,
              backgroundColor: statusBgColor,
              borderColor: statusBorderColor,
              size: CapsuleSize.medium,
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Subtitle Varietas
        Text(
          'Varietas: $variety',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: 13,
            color: Color.fromRGBO(107, 114, 128, 1),
          ),
        ),

        const SizedBox(height: 4),

        // Info Semaian & HSS (Tanggal + Jumlah Bibit • X HSS)
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: Color.fromRGBO(156, 163, 175, 1),
            ),
            children: [
              TextSpan(text: 'Semaian: $dateText '),
              TextSpan(
                text: '$seedCountText • $hssText',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color.fromRGBO(31, 41, 55, 1),
                ),
              ),
            ],
          ),
        ),

        // Box Catatan/Rekomendasi (Jika ada)
        if (note != null && note!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(255, 248, 243, 1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color.fromRGBO(254, 215, 170, 1),
                width: 1.0,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color.fromRGBO(249, 115, 22, 1),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    note!,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color.fromRGBO(194, 65, 12, 1),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
