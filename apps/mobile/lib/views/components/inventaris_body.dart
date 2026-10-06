import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/inventory_record.dart';
import '../../models/inventory_item_model.dart' show StockStatus;
import '../../viewmodels/connected_inventory_viewmodel.dart';
import '../widgets/custom_search_bar.dart';
import '../widgets/filter_button.dart';
import '../widgets/row_info_card_md.dart';
import '../widgets/card_icon_box.dart';
import '../widgets/stock_status_badge.dart';
import '../widgets/item_info_details.dart';
import '../widgets/row_button.dart';
import '../pages/add_form_inventaris_page.dart';

class InventarisBody extends ConsumerStatefulWidget {
  const InventarisBody({super.key});

  @override
  ConsumerState<InventarisBody> createState() => _InventarisBodyState();
}

class _InventarisBodyState extends ConsumerState<InventarisBody> {
  String _searchQuery = '';
  String _selectedCategory = 'Semua';

  void _showDetail(InventoryRecord item) {
    showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: Text(item.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Jenis: ${item.category}'),
              const SizedBox(height: 12),
              Text('Saldo: ${item.formattedStock}'),
              const SizedBox(height: 12),
              Text(
                item.minimum == null
                    ? 'Stok minimum belum ditetapkan.'
                    : 'Stok minimum: ${item.minimum} ${item.unit}',
              ),
              const SizedBox(height: 12),
              Text(_stockLabel(item)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  String _stockLabel(InventoryRecord item) {
    if (item.isOutOfStock) return 'Stok habis';
    if (item.isLow) return 'Di bawah stok minimum';
    return item.minimum == null ? 'Stok tersedia' : 'Stok mencukupi';
  }

  StockStatus _statusFor(InventoryRecord item) {
    if (item.isOutOfStock) return StockStatus.habis;
    if (item.isLow) return StockStatus.menipis;
    return StockStatus.aman;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(connectedInventoryProvider);
    final refresh = ref.read(connectedInventoryProvider.notifier).refresh;

    final activeItems = state.records.where((i) => i.active).toList();
    final dynamicCategories = <String>{'Semua', ...activeItems.map((i) => i.category)}.toList();

    final filtered = activeItems.where((item) {
      final matchCat = _selectedCategory == 'Semua' || item.category == _selectedCategory;
      final matchQuery = item.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchCat && matchQuery;
    }).toList();

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color.fromRGBO(250, 250, 247, 1),
      child: RefreshIndicator(
        onRefresh: refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.cached)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(255, 248, 243, 1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color.fromRGBO(255, 154, 85, 0.5)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.offline_pin_outlined, size: 18, color: Color.fromRGBO(255, 154, 85, 1)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Menampilkan salinan lokal. Saldo mungkin sudah berubah.',
                          style: TextStyle(fontSize: 11, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              if (state.error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(254, 242, 242, 1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color.fromRGBO(239, 68, 68, 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 18, color: Color.fromRGBO(239, 68, 68, 1)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.error!,
                          style: const TextStyle(fontSize: 11, color: Color.fromRGBO(239, 68, 68, 1)),
                        ),
                      ),
                    ],
                  ),
                ),
              CustomSearchBar(
                placeholder: 'Cari nama barang...',
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: dynamicCategories.map((cat) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 10.0),
                      child: FilterButton(
                        label: cat,
                        isSelected: _selectedCategory == cat,
                        onTap: () => setState(() => _selectedCategory = cat),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              if (state.loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: CircularProgressIndicator(color: Color.fromRGBO(57, 198, 195, 1)),
                  ),
                )
              else if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32.0),
                  child: Center(
                    child: Text(
                      state.error != null && activeItems.isEmpty
                          ? 'Data inventaris belum dapat ditampilkan.'
                          : activeItems.isEmpty
                          ? 'Belum ada barang inventaris aktif.'
                          : 'Tidak ada barang yang cocok.',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: Color.fromRGBO(156, 163, 175, 1),
                      ),
                    ),
                  ),
                )
              else
                ...filtered.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: RowInfoCardMd(
                      backgroundColor: Colors.white,
                      borderColor: const Color.fromRGBO(229, 231, 235, 1),
                      onTap: () => _showDetail(item),
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
                              categoryColor: const Color.fromRGBO(57, 198, 195, 1),
                              categoryBgColor: const Color.fromRGBO(237, 249, 248, 1),
                            ),
                          ),
                          const SizedBox(width: 8),
                          StockStatusBadge(status: _statusFor(item)),
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
      ),
    );
  }
}
