import 'package:flutter/material.dart';

class ItemInfoDetails extends StatelessWidget {
  final String name;
  final String category;
  final String stockText;
  final Color categoryColor;
  final Color categoryBgColor;

  const ItemInfoDetails({
    super.key,
    required this.name,
    required this.category,
    required this.stockText,
    required this.categoryColor,
    required this.categoryBgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Nama Barang
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: Colors.black,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        // Baris Kategori + Dot + Stok
        Row(
          children: [
            // Capsule Kategori
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: categoryBgColor,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                category,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                  color: categoryColor,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Titik pemisah (Dot)
            const SizedBox(
              width: 3,
              height: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Teks Stok
            Expanded(
              child: Text(
                'Stok: $stockText',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: Colors.black87,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}