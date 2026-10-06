import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/seeding_batch_model.dart';
import '../components/header.dart';
import '../widgets/base_col_card.dart';
import '../widgets/col_button.dart';
import 'seeding_form_page.dart';

class InfoSeedingPage extends ConsumerWidget {
  final SeedingBatch seedingItem;

  const InfoSeedingPage({super.key, required this.seedingItem});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const Header(
        titleText: 'Detail Penyemaian',
        showBackButton: true,
      ),
      backgroundColor: const Color.fromRGBO(250, 250, 247, 1),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER INFO BATCH ---
            Text(
              'Batch Penyemaian #${seedingItem.batchNumber}',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: Color.fromRGBO(23, 34, 49, 1),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Varietas: ${seedingItem.variety}',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color.fromRGBO(107, 114, 128, 1),
              ),
            ),
            const SizedBox(height: 20),

            // --- PROGRES USIA SEMAI CARD ---
            BaseColCard(
              backgroundColor: Colors.white,
              borderColor: const Color.fromRGBO(243, 244, 246, 1),
              borderRadius: 20,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Progres Usia Semai',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color.fromRGBO(107, 114, 128, 1),
                        ),
                      ),
                      Text(
                        '${seedingItem.hss} dari ${seedingItem.totalHss} Hari',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color.fromRGBO(23, 34, 49, 1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: seedingItem.progressRatio,
                      minHeight: 10,
                      backgroundColor: const Color.fromRGBO(229, 231, 235, 1),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color.fromRGBO(57, 198, 195, 1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Rencana pindah tanam: Besok (HSS ${seedingItem.totalHss})',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: Color.fromRGBO(156, 163, 175, 1),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // --- SUMMARY CARDS (BIBIT SEHAT & RUSAK) ---
            Row(
              children: [
                Expanded(
                  child: BaseColCard(
                    backgroundColor: Colors.white,
                    borderColor: const Color.fromRGBO(243, 244, 246, 1),
                    borderRadius: 20,
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bibit Sehat',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: Color.fromRGBO(107, 114, 128, 1),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${seedingItem.healthyCount} Bibit',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color.fromRGBO(23, 34, 49, 1),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          seedingItem.healthyPhase,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Color.fromRGBO(156, 163, 175, 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BaseColCard(
                    backgroundColor: Colors.white,
                    borderColor: const Color.fromRGBO(243, 244, 246, 1),
                    borderRadius: 20,
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bibit Rusak',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: Color.fromRGBO(107, 114, 128, 1),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${seedingItem.damagedCount} Bibit',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color.fromRGBO(23, 34, 49, 1),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          seedingItem.damagedNote,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Color.fromRGBO(156, 163, 175, 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- BAHAN YANG DIGUNAKAN SECTION ---
            if (seedingItem.materials.isNotEmpty) ...[
              const Text(
                'BAHAN YANG DIGUNAKAN',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: Color.fromRGBO(107, 114, 128, 1),
                ),
              ),
              const SizedBox(height: 12),
              BaseColCard(
                backgroundColor: Colors.white,
                borderColor: const Color.fromRGBO(243, 244, 246, 1),
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: seedingItem.materials.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '• ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color.fromRGBO(23, 34, 49, 1),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              item,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color.fromRGBO(23, 34, 49, 1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 28),
            ],

            // --- ACTION BUTTONS ---
            Row(
              children: [
                Expanded(
                  child: ColButton(
                    text: 'Edit Semai',
                    textColor: const Color.fromRGBO(57, 198, 195, 1),
                    backgroundColor: Colors.white,
                    borderColor: const Color.fromRGBO(57, 198, 195, 1),
                    height: 52,
                    borderRadius: 25,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SeedingFormPage(
                            seedingItem: seedingItem,
                          ), // Edit Mode
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ColButton(
                    text: 'Pindahkan ke Meja NFT',
                    textColor: Colors.white,
                    backgroundColor: const Color.fromRGBO(23, 34, 49, 1),
                    borderColor: const Color.fromRGBO(23, 34, 49, 1),
                    height: 52,
                    borderRadius: 25,
                    fontSize: 13.5,
                    onPressed: () {
                      // Action pindahkan ke Meja NFT
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
