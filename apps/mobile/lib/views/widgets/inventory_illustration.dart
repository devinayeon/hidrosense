import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../data/models/inventory_record.dart';

class InventoryIllustration extends StatelessWidget {
  const InventoryIllustration({super.key, required this.asset, this.size = 72});

  static const overview = 'assets/illustrations/features/inventory-stock.png';
  static const empty = 'assets/illustrations/states/empty-inventory.png';
  static const noResults = 'assets/illustrations/states/no-search-results.png';
  static const avatar = 'assets/illustrations/avatars/mascot-avatar.png';

  static String forItem(InventoryRecord item) {
    final name = item.name.trim().toLowerCase();
    const overrides = {
      'benih selada romaine': 'item-romaine-seeds',
      'benih selada butterhead': 'item-butterhead-seeds',
      'nutrisi ab mix sayuran daun': 'item-abmix-nutrients',
      'insektisida abamectin': 'item-plant-care',
      'rockwool semai standar': 'item-rockwool',
    };
    final exact = overrides[name];
    if (exact != null) return 'assets/illustrations/inventory/$exact.png';
    final category = item.category.trim().toLowerCase();
    final String? fallback;
    if (category.contains('benih')) {
      fallback = 'category-seeds';
    } else if (category.contains('nutrisi') || category.contains('pupuk')) {
      fallback = 'item-abmix-nutrients';
    } else if (category.contains('obat') || category.contains('pestisida')) {
      fallback = 'item-plant-care';
    } else if (category.contains('perlengkapan') ||
        category.contains('peralatan') ||
        category.contains('media tanam')) {
      fallback = 'item-rockwool';
    } else {
      fallback = null;
    }
    return fallback == null
        ? overview
        : 'assets/illustrations/inventory/$fallback.png';
  }

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      cacheWidth: 512,
      errorBuilder: (_, _, _) => SizedBox(
        width: size,
        height: size,
        child: Icon(
          CupertinoIcons.cube_box,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    ),
  );
}
