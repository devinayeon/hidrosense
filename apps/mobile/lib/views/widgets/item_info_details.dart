import 'package:flutter/material.dart';
import 'capsule_badge.dart';

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
        Row(
          children: [
            Flexible(
              child: CapsuleBadge(
                label: category,
                textColor: categoryColor,
                backgroundColor: categoryBgColor,
                size: CapsuleSize.small,
              ),
            ),
            const SizedBox(width: 6),
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
