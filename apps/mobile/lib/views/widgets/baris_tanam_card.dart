// lib/views/widgets/baris_tanam_card.dart
import 'package:flutter/material.dart';
import '../../models/baris_tanam_model.dart';
import 'capsule_badge.dart';
import 'row_info_card_md.dart';

class BarisTanamCard extends StatelessWidget {
  final BarisTanam item;

  const BarisTanamCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final bool isPerfect = item.isPerfect;

    // Skema warna berdasarkan kondisi
    final Color borderColor = isPerfect
        ? const Color.fromRGBO(240, 240, 235, 1)
        : const Color.fromRGBO(254, 215, 170, 1); // Border oranye soft
    final Color badgeBgColor = isPerfect
        ? const Color.fromRGBO(224, 247, 246, 1)
        : const Color.fromRGBO(255, 237, 213, 1);
    final Color badgeTextColor = isPerfect
        ? const Color.fromRGBO(57, 198, 195, 1)
        : const Color.fromRGBO(249, 115, 22, 1);
    final Color badgeBorderColor = isPerfect
        ? const Color.fromRGBO(57, 198, 195, 0.4)
        : const Color.fromRGBO(249, 115, 22, 0.4);

    final String statusBadgeText = isPerfect
        ? '100% Ok'
        : '${item.failedCount} Rusak';

    return RowInfoCardMd(
      backgroundColor: Colors.white,
      borderColor: borderColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Sisi Kiri: Judul & Informasi Detail
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.name} (${item.holesRange})',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color.fromRGBO(23, 34, 49, 1),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (isPerfect) ...[
                      CapsuleBadge(
                        label: '${item.totalBibit} Bibit',
                        textColor: const Color.fromRGBO(57, 198, 195, 1),
                        backgroundColor: const Color.fromRGBO(240, 253, 250, 1),
                        size: CapsuleSize.small,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '•  Sehat • Usia ${item.hss} HSS',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Color.fromRGBO(55, 65, 81, 1),
                        ),
                      ),
                    ] else ...[
                      CapsuleBadge(
                        label: '${item.healthyCount} Sehat',
                        textColor: const Color.fromRGBO(249, 115, 22, 1),
                        backgroundColor: const Color.fromRGBO(255, 247, 237, 1),
                        size: CapsuleSize.small,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '•  ${item.failedCount} Gagal Tumbuh / Busuk',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: Color.fromRGBO(55, 65, 81, 1),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Sisi Kanan: Badge Indikator Status Persentase / Rusak
          CapsuleBadge(
            label: statusBadgeText,
            textColor: badgeTextColor,
            backgroundColor: badgeBgColor,
            borderColor: badgeBorderColor,
            size: CapsuleSize.medium,
            fontWeight: FontWeight.w700,
          ),
        ],
      ),
    );
  }
}
