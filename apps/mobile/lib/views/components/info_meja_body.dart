// lib/views/components/info_meja_body.dart
import 'package:flutter/material.dart';
import '../../models/meja_nft_model.dart';
import '../pages/detail_tanaman_meja_page.dart';
import '../pages/form_meja_nft_page.dart';
import '../widgets/row_info_card_md.dart';
import '../widgets/row_button.dart';

class InfoMejaBody extends StatelessWidget {
  final MejaNft mejaItem;

  const InfoMejaBody({super.key, required this.mejaItem});

  @override
  Widget build(BuildContext context) {
    final occupancyPercent = (mejaItem.occupancyPercentage * 100).toInt();

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color.fromRGBO(250, 250, 247, 1),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Title & Subtitle Header
            Text(
              mejaItem.name,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: Color.fromRGBO(23, 34, 49, 1),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${mejaItem.systemType} • ${mejaItem.location}',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: Color.fromRGBO(156, 163, 175, 1),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Card Okupansi Lubang
            RowInfoCardMd(
              backgroundColor: Colors.white,
              borderColor: const Color.fromRGBO(240, 240, 235, 1),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Okupansi Lubang',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Color.fromRGBO(107, 114, 128, 1),
                        ),
                      ),
                      Text(
                        '${mejaItem.capacityUsed} / ${mejaItem.capacityTotal} Terisi ($occupancyPercent%)',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Progress Bar Okupansi
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: mejaItem.occupancyPercentage,
                      minHeight: 10,
                      backgroundColor: const Color.fromRGBO(243, 244, 246, 1),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color.fromRGBO(57, 198, 195, 1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Detail Tanaman Sehat & Kosong/Gagal
                  Row(
                    children: [
                      Text(
                        '• ${mejaItem.healthyCount} Tanaman Sehat',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Color.fromRGBO(107, 114, 128, 1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '• ${mejaItem.failedCount} Kosong / Gagal',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                          color: Color.fromRGBO(249, 115, 22, 1),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 3. Card Batch Aktif Saat Ini
            if (mejaItem.status == MejaStatus.aktif)
              RowInfoCardMd(
                backgroundColor: Colors.white,
                borderColor: const Color.fromRGBO(240, 240, 235, 1),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BATCH AKTIF SAAT INI',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        letterSpacing: 0.3,
                        color: Color.fromRGBO(107, 114, 128, 1),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${mejaItem.batchName ?? "-"} - ${mejaItem.variety ?? "-"}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Usia Tanaman:',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: Color.fromRGBO(107, 114, 128, 1),
                          ),
                        ),
                        Text(
                          '${mejaItem.hss ?? 0} HSS (Hari Setelah Semai)',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Estimasi Panen:',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: Color.fromRGBO(107, 114, 128, 1),
                          ),
                        ),
                        Text(
                          mejaItem.estimatedHarvestDate ?? '-',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              // Tampilan saat Perawatan
              RowInfoCardMd(
                backgroundColor: Colors.white,
                borderColor: const Color.fromRGBO(240, 240, 235, 1),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'STATUS PERAWATAN',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Color.fromRGBO(217, 119, 6, 1),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      mejaItem.maintenanceNote ?? 'Dalam Perawatan',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.black,
                      ),
                    ),
                    if (mejaItem.maintenanceEta != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        mejaItem.maintenanceEta!,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: Color.fromRGBO(107, 114, 128, 1),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // 4. Tombol Utama (Lihat Tanaman pada Meja)
            RowButton(
              label: 'Lihat Tanaman pada Meja',
              backgroundColor: const Color.fromRGBO(57, 198, 195, 1),
              textColor: Colors.white,
              borderRadius: 24,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        DetailTanamanMejaPage(mejaItem: mejaItem),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // 5. Tombol Sekunder (Edit Pengaturan Meja)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                    color: Color.fromRGBO(57, 198, 195, 1),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  backgroundColor: Colors.transparent,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          FormMejaNftPage(mejaItem: mejaItem), // Mode Edit
                    ),
                  );
                },
                child: const Text(
                  'Edit Pengaturan Meja',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color.fromRGBO(57, 198, 195, 1),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
