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
  });

  String get formattedStock => '${stockValue.toInt()} $stockUnit';

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
    );
  }
}
