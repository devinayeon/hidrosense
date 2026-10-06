// lib/views/components/panen_body.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/panen_viewmodel.dart';
import '../pages/laporan_panen_page.dart';
import '../pages/panen_form_page.dart';
import '../widgets/filter_button.dart';
import '../widgets/panen_card.dart';
import '../widgets/row_button.dart';

class PanenBody extends ConsumerWidget {
  const PanenBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allPanenList = ref.watch(panenViewModelProvider);
    final activeFilter = ref.watch(panenFilterCategoryProvider);
    final panenList = ref.watch(filteredPanenListProvider);

    // Hitung jumlah dinamik untuk badge tab
    final upcomingCount = allPanenList.where((item) => item.isEstimasi).length;
    final completedCount = allPanenList
        .where((item) => !item.isEstimasi)
        .length;

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
                  // 1. Filter Tab Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        FilterButton(
                          label: 'Semua Data',
                          isSelected: activeFilter == PanenFilterCategory.all,
                          onTap: () {
                            ref
                                    .read(panenFilterCategoryProvider.notifier)
                                    .state =
                                PanenFilterCategory.all;
                          },
                        ),
                        const SizedBox(width: 8),
                        FilterButton(
                          label: 'Mendatang ($upcomingCount)',
                          isSelected:
                              activeFilter == PanenFilterCategory.upcoming,
                          onTap: () {
                            ref
                                    .read(panenFilterCategoryProvider.notifier)
                                    .state =
                                PanenFilterCategory.upcoming;
                          },
                        ),
                        const SizedBox(width: 8),
                        FilterButton(
                          label: 'Selesai ($completedCount)',
                          isSelected:
                              activeFilter == PanenFilterCategory.completed,
                          onTap: () {
                            ref
                                    .read(panenFilterCategoryProvider.notifier)
                                    .state =
                                PanenFilterCategory.completed;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Daftar Panen Cards
                  if (panenList.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'Tidak ada data panen.',
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
                      itemCount: panenList.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final panenItem = panenList[index];
                        return PanenCard(
                          item: panenItem,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    LaporanPanenPage(item: panenItem),
                              ),
                            );
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
          ),

          // 3. Bottom Button: + Catat Hasil Panen Baru
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color.fromRGBO(250, 250, 247, 1),
            child: SafeArea(
              child: RowButton(
                label: '+ Catat Hasil Panen Baru',
                backgroundColor: const Color.fromRGBO(23, 34, 49, 1),
                textColor: const Color.fromRGBO(221, 244, 90, 1),
                borderRadius: 16,
                height: 52,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PanenFormPage(),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
