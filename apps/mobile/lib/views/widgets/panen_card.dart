// lib/views/widgets/panen_card.dart
import 'package:flutter/material.dart';
import '../../models/panen_model.dart';
import 'capsule_badge.dart';
import 'row_info_card_md.dart';

class PanenCard extends StatelessWidget {
  final PanenItem item;
  final VoidCallback? onTap;

  const PanenCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool isEstimasi = item.isEstimasi;

    // Styling Badge berdasarkan status
    final String badgeLabel = isEstimasi ? 'Estimasi' : 'Selesai';
    final Color badgeBgColor = isEstimasi
        ? const Color.fromRGBO(224, 247, 246, 1)
        : const Color.fromRGBO(236, 253, 245, 1);
    final Color badgeTextColor = isEstimasi
        ? const Color.fromRGBO(57, 198, 195, 1)
        : const Color.fromRGBO(34, 197, 94, 1);
    final Color badgeBorderColor = isEstimasi
        ? const Color.fromRGBO(57, 198, 195, 0.4)
        : const Color.fromRGBO(34, 197, 94, 0.4);

    // Dynamic subtitle (Meja info, HSS, Tanggal)
    final String subtitleText = item.targetHss != null
        ? '${item.mejaInfo} • ${item.targetHss} • ${item.dateText}'
        : '${item.mejaInfo} • ${item.dateText}';

    return RowInfoCardMd(
      backgroundColor: Colors.white,
      borderColor: const Color.fromRGBO(240, 240, 235, 1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris Atas: Judul Batch & Badge Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color.fromRGBO(23, 34, 49, 1),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CapsuleBadge(
                label: badgeLabel,
                textColor: badgeTextColor,
                backgroundColor: badgeBgColor,
                borderColor: badgeBorderColor,
                size: CapsuleSize.medium,
                fontWeight: FontWeight.w600,
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Baris Tengah: Info Meja / HSS / Tanggal
          Text(
            subtitleText,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: 12,
              color: Color.fromRGBO(107, 114, 128, 1),
            ),
          ),
          const SizedBox(height: 6),

          // Baris Bawah: Detail Hasil / Estimasi
          Text(
            item.resultText,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: Color.fromRGBO(31, 41, 55, 1),
            ),
          ),
        ],
      ),
    );
  }
}
