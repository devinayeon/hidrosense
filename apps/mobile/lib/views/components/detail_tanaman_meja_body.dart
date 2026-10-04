// lib/views/components/detail_tanaman_meja_body.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/meja_nft_model.dart';
import '../../viewmodels/baris_tanam_viewmodel.dart';
import '../pages/catat_kerusakan_page.dart';
import '../widgets/baris_tanam_card.dart';
import '../widgets/filter_button.dart';
// import '../widgets/row_button.dart';

class DetailTanamanMejaBody extends ConsumerWidget {
  final MejaNft mejaItem;

  const DetailTanamanMejaBody({super.key, required this.mejaItem});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFilter = ref.watch(barisFilterCategoryProvider);
    final barisList = ref.watch(filteredBarisTanamListProvider);

    final String batchTitle =
        '${mejaItem.batchName ?? "Batch #03"} - ${mejaItem.variety ?? "Selada Grand Rapids"}';

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color.fromRGBO(250, 250, 247, 1),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Title & Subtitle Batch Info
                  Text(
                    batchTitle,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: Color.fromRGBO(23, 34, 49, 1),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Berikut adalah data detail per baris / lubang tanam',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: Color.fromRGBO(156, 163, 175, 1),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Bar Filter Kategori
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        FilterButton(
                          label: 'Semua Baris',
                          isSelected: activeFilter == BarisFilterCategory.all,
                          onTap: () {
                            ref
                                    .read(barisFilterCategoryProvider.notifier)
                                    .state =
                                BarisFilterCategory.all;
                          },
                        ),
                        const SizedBox(width: 8),
                        FilterButton(
                          label: 'Kondisi Baik',
                          isSelected: activeFilter == BarisFilterCategory.good,
                          onTap: () {
                            ref
                                    .read(barisFilterCategoryProvider.notifier)
                                    .state =
                                BarisFilterCategory.good;
                          },
                        ),
                        const SizedBox(width: 8),
                        FilterButton(
                          label: 'Kondisi Rusak',
                          isSelected:
                              activeFilter == BarisFilterCategory.damaged,
                          onTap: () {
                            ref
                                    .read(barisFilterCategoryProvider.notifier)
                                    .state =
                                BarisFilterCategory.damaged;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. List Cards Baris Tanam
                  if (barisList.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'Tidak ada data baris tanam.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: Color.fromRGBO(156, 163, 175, 1),
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: barisList.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return BarisTanamCard(item: barisList[index]);
                      },
                    ),
                ],
              ),
            ),
          ),

          // 4. Sticky Bottom Action Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color.fromRGBO(250, 250, 247, 1),
            ),
            child: SafeArea(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: const BorderSide(
                    color: Color.fromRGBO(57, 198, 195, 1),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  backgroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          CatatKerusakanPage(mejaItem: mejaItem),
                    ),
                  );
                },
                child: const Text(
                  'Catat Tanaman Rusak / Gagal',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color.fromRGBO(57, 198, 195, 1),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
