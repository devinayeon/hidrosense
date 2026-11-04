import 'package:flutter/material.dart';

/// Ilustrasi fitur yang dipakai bersama oleh layar utama.
///
/// Aset mengikuti gaya inventaris: satu ilustrasi fokus per layar, ukuran
/// besar untuk kartu ringkasan dan ukuran kecil untuk state kosong.
class FeatureIllustration extends StatelessWidget {
  const FeatureIllustration({super.key, required this.asset, this.size = 72});

  static const inventory = 'assets/illustrations/features/inventory-stock.png';
  static const nursery = 'assets/illustrations/features/nursery-seedlings.png';
  static const sales = 'assets/illustrations/features/sales-produce.png';
  static const table = 'assets/illustrations/features/nft-growing-table.png';
  static const harvest = 'assets/illustrations/features/harvest-lettuce.png';
  static const weather = 'assets/illustrations/features/weather-greenhouse.png';
  static const emptyNursery = 'assets/illustrations/states/empty-nursery.png';
  static const emptyInventory =
      'assets/illustrations/states/empty-inventory.png';
  static const noResults = 'assets/illustrations/states/no-search-results.png';

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return ExcludeSemantics(
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        cacheWidth: 512,
        errorBuilder: (_, _, _) => SizedBox(
          width: size,
          height: size,
          child: Icon(Icons.eco_outlined, color: color),
        ),
      ),
    );
  }
}
