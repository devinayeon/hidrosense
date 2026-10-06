import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../viewmodels/penjualan_viewmodel.dart';
import '../pages/catat_penjualan_page.dart';
import '../widgets/custom_search_bar.dart';
import '../widgets/penjualan_card.dart';
import '../widgets/row_button.dart';
import '../widgets/row_info_card_md.dart';

class PenjualanBody extends ConsumerWidget {
  const PenjualanBody({super.key});

  void _showFilterBottomSheet(BuildContext context, WidgetRef ref) {
    final activeFilter = ref.read(penjualanFilterCategoryProvider);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter Status Penjualan',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Semua Status'),
                trailing: activeFilter == PenjualanFilterCategory.all
                    ? const Icon(
                        Icons.check,
                        color: Color.fromRGBO(57, 198, 195, 1),
                      )
                    : null,
                onTap: () {
                  ref.read(penjualanFilterCategoryProvider.notifier).state =
                      PenjualanFilterCategory.all;
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Lunas'),
                trailing: activeFilter == PenjualanFilterCategory.lunas
                    ? const Icon(
                        Icons.check,
                        color: Color.fromRGBO(57, 198, 195, 1),
                      )
                    : null,
                onTap: () {
                  ref.read(penjualanFilterCategoryProvider.notifier).state =
                      PenjualanFilterCategory.lunas;
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Belum Lunas'),
                trailing: activeFilter == PenjualanFilterCategory.belumLunas
                    ? const Icon(
                        Icons.check,
                        color: Color.fromRGBO(57, 198, 195, 1),
                      )
                    : null,
                onTap: () {
                  ref.read(penjualanFilterCategoryProvider.notifier).state =
                      PenjualanFilterCategory.belumLunas;
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final penjualanList = ref.watch(filteredPenjualanListProvider);
    final allCount = ref.watch(penjualanViewModelProvider).length;
    final totalPendapatan = ref.watch(totalPendapatanBulanIniProvider);

    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

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
                  // 1. Top Card Total Pendapatan Bulan Ini
                  RowInfoCardMd(
                    backgroundColor: const Color.fromRGBO(57, 198, 195, 1),
                    borderColor: const Color.fromRGBO(57, 198, 195, 1),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Total Pendapatan Bulan Ini',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currencyFormatter.format(totalPendapatan),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w800,
                            fontSize: 24,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Dari total $allCount transaksi penjualan terlaksana',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Baris Search & Filter Button
                  Row(
                    children: [
                      Expanded(
                        child: CustomSearchBar(
                          placeholder: 'Cari pembeli...',
                          onChanged: (val) {
                            ref
                                    .read(penjualanSearchQueryProvider.notifier)
                                    .state =
                                val;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _showFilterBottomSheet(context, ref),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(243, 244, 246, 1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(
                            child: Text(
                              'Filter',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: Color.fromRGBO(55, 65, 81, 1),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 3. Daftar Card Penjualan
                  if (penjualanList.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'Tidak ada data penjualan.',
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
                      itemCount: penjualanList.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return PenjualanCard(
                          item: penjualanList[index],
                          onTap: () {
                            // Action detail transaksi penjualan
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
          ),

          // 4. Bottom Action Button: + Catat Penjualan Baru
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color.fromRGBO(250, 250, 247, 1),
            child: SafeArea(
              child: RowButton(
                label: '+ Catat Penjualan Baru',
                backgroundColor: const Color.fromRGBO(23, 34, 49, 1),
                textColor: const Color.fromRGBO(221, 244, 90, 1),
                borderRadius: 16,
                height: 52,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CatatPenjualanPage(),
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
