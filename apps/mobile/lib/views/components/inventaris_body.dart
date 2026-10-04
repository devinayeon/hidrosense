import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/inventaris_viewmodel.dart';
import '../widgets/custom_search_bar.dart';
import '../widgets/filter_button.dart';
import '../widgets/row_info_card_md.dart';
import '../widgets/card_icon_box.dart';
import '../widgets/stock_status_badge.dart';
import '../widgets/item_info_details.dart';
import '../widgets/row_button.dart';
import '../pages/info_item_inventaris_page.dart';
import '../pages/add_form_inventaris_page.dart';

class InventarisBody extends ConsumerWidget {
  const InventarisBody({super.key});

  final List<String> _categories = const [
    'Semua',
    'Benih',
    'Pupuk',
    'Obat',
    'Peralatan',
    'Media Tanam',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inventarisViewModelProvider);
    final viewModel = ref.read(inventarisViewModelProvider.notifier);

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
            CustomSearchBar(
              placeholder: 'Cari nama barang...',
              onChanged: viewModel.setSearchQuery,
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _categories.map((cat) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 10.0),
                    child: FilterButton(
                      label: cat,
                      isSelected: state.selectedCategory == cat,
                      onTap: () => viewModel.setCategory(cat),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            if (state.isLoading)
              const Center(child: CircularProgressIndicator())
            else
              ...state.filteredItems.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: RowInfoCardMd(
                    backgroundColor: Colors.white,
                    borderColor: const Color.fromRGBO(229, 231, 235, 1),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              InfoItemInventarisPage(item: item),
                        ),
                      );
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const CardIconBox(
                          iconData: Icons.inventory_2_outlined,
                          backgroundColor: Color.fromRGBO(237, 249, 248, 1),
                          iconColor: Color.fromRGBO(57, 198, 195, 1),
                          width: 44,
                          height: 44,
                          borderRadius: 14,
                          iconSize: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ItemInfoDetails(
                            name: item.name,
                            category: item.category,
                            stockText: item.formattedStock,
                            categoryColor: const Color.fromRGBO(
                              57,
                              198,
                              195,
                              1,
                            ),
                            categoryBgColor: const Color.fromRGBO(
                              237,
                              249,
                              248,
                              1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        StockStatusBadge(status: item.status),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 8),
            RowButton(
              label: '+ Tambah Barang Baru',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddFormInventarisPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
