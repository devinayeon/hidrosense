import 'package:flutter/material.dart';

enum StockStatus { aman, menipis, habis }

class InventoryItem {
  final String id;
  final String name;
  final String category;
  final double stockValue;
  final String stockUnit;
  final String mainUnit;
  final double price;
  final String note;
  final String? imageUrl;
  final StockStatus status;
  final bool isDeleted; // Soft delete flag

  InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.stockValue,
    required this.stockUnit,
    required this.mainUnit,
    this.price = 0,
    this.note = '',
    this.imageUrl,
    required this.status,
    this.isDeleted = false,
  });

  String get formattedStock => '${stockValue.toInt()} $stockUnit';

  InventoryItem copyWith({
    String? id,
    String? name,
    String? category,
    double? stockValue,
    String? stockUnit,
    String? mainUnit,
    double? price,
    String? note,
    String? imageUrl,
    StockStatus? status,
    bool? isDeleted,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      stockValue: stockValue ?? this.stockValue,
      stockUnit: stockUnit ?? this.stockUnit,
      mainUnit: mainUnit ?? this.mainUnit,
      price: price ?? this.price,
      note: note ?? this.note,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? 'Umum',
      stockValue: (json['stockValue'] as num?)?.toDouble() ?? 0,
      stockUnit: json['stockUnit'] ?? '',
      mainUnit: json['mainUnit'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      note: json['note'] ?? '',
      imageUrl: json['imageUrl'],
      status: StockStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => StockStatus.aman,
      ),
      isDeleted: json['isDeleted'] ?? false,
    );
  }
}
