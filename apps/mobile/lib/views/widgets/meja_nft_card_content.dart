// lib/views/widgets/meja_nft_card_content.dart
import 'package:flutter/material.dart';
import '../../models/meja_nft_model.dart';
import 'capsule_badge.dart';

class MejaNftCardContent extends StatelessWidget {
  final MejaNft item;

  const MejaNftCardContent({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final isAktif = item.status == MejaStatus.aktif;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              item.name,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Colors.black,
              ),
            ),
            CapsuleBadge(
              label: isAktif ? 'Aktif' : 'Perawatan',
              textColor: isAktif
                  ? const Color.fromRGBO(2, 132, 199, 1)
                  : const Color.fromRGBO(217, 119, 6, 1),
              backgroundColor: isAktif
                  ? const Color.fromRGBO(224, 242, 254, 1)
                  : const Color.fromRGBO(254, 243, 199, 1),
              size: CapsuleSize.small,
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (isAktif) ...[
          Text(
            'Kapasitas: ${item.capacityUsed} / ${item.capacityTotal} Lubang Terisi',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: Color.fromRGBO(107, 114, 128, 1),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${item.batchName ?? ""} • ${item.variety ?? ""} (${item.hss ?? 0} HSS)',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: 12,
              color: Color.fromRGBO(107, 114, 128, 1),
            ),
          ),
        ] else ...[
          Text(
            'Kapasitas: Kosong (${item.maintenanceNote ?? "Dalam Perawatan"})',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: Color.fromRGBO(107, 114, 128, 1),
            ),
          ),
          if (item.maintenanceEta != null) ...[
            const SizedBox(height: 2),
            Text(
              item.maintenanceEta!,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: Color.fromRGBO(156, 163, 175, 1),
              ),
            ),
          ],
        ],
      ],
    );
  }
}
