import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/inventory_item_model.dart';

class InventarisState {
  final List<InventoryItem> items;
  final String selectedCategory;
  final String searchQuery;
  final bool isLoading;

  InventarisState({
    this.items = const [],
    this.selectedCategory = 'Semua',
    this.searchQuery = '',
    this.isLoading = false,
  });

  InventarisState copyWith({
    List<InventoryItem>? items,
    String? selectedCategory,
    String? searchQuery,
    bool? isLoading,
  }) {
    return InventarisState(
      items: items ?? this.items,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  // Saring hanya item yang BELUM di-soft delete (!item.isDeleted)
  List<InventoryItem> get filteredItems {
    return items.where((item) {
      if (item.isDeleted) return false;
      final matchesCategory =
          selectedCategory == 'Semua' || item.category == selectedCategory;
      final matchesQuery = item.name.toLowerCase().contains(
        searchQuery.toLowerCase(),
      );
      return matchesCategory && matchesQuery;
    }).toList();
  }
}

class InventarisViewModel extends StateNotifier<InventarisState> {
  InventarisViewModel() : super(InventarisState()) {
    fetchInventory();
  }

  Future<void> fetchInventory() async {
    state = state.copyWith(isLoading: true);
    await Future.delayed(const Duration(milliseconds: 300));

    final mockItems = [
      InventoryItem(
        id: '1',
        name: 'Benih Selada Grand Rapids',
        category: 'Benih',
        stockValue: 5000,
        stockUnit: 'btr',
        mainUnit: 'Butir (Btr)',
        status: StockStatus.aman,
      ),
      InventoryItem(
        id: '2',
        name: 'Pupuk AB Mix Selada',
        category: 'Pupuk',
        stockValue: 45,
        stockUnit: 'Kg',
        mainUnit: 'Kilogram (Kg)',
        price: 150000,
        status: StockStatus.menipis,
      ),
      InventoryItem(
        id: '3',
        name: 'Rockwool Media Tanam',
        category: 'Media Tanam',
        stockValue: 12,
        stockUnit: 'Blok',
        mainUnit: 'Blok',
        status: StockStatus.aman,
      ),
    ];

    state = state.copyWith(items: mockItems, isLoading: false);
  }

  // Method Tambah Barang Baru
  void addItem(InventoryItem newItem) {
    state = state.copyWith(items: [...state.items, newItem]);
  }

  // Method Edit Barang
  void updateItem(InventoryItem updatedItem) {
    final updatedList = state.items.map((item) {
      return item.id == updatedItem.id ? updatedItem : item;
    }).toList();
    state = state.copyWith(items: updatedList);
  }

  // Method Soft Delete / Nonaktifkan Barang
  void softDeleteItem(String itemId) {
    final updatedList = state.items.map((item) {
      if (item.id == itemId) {
        return item.copyWith(isDeleted: true);
      }
      return item;
    }).toList();
    state = state.copyWith(items: updatedList);
  }

  void setCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }
}

final inventarisViewModelProvider =
    StateNotifierProvider<InventarisViewModel, InventarisState>((ref) {
      return InventarisViewModel();
    });
