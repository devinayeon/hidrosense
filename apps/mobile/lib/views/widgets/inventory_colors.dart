import 'package:flutter/material.dart';

import 'app_surface_colors.dart';

/// Nama lama untuk [AppSurfaceColors].
///
/// Dipertahankan agar komponen inventaris yang sudah ada tetap memakai API
/// yang sama, sementara layar lain dapat memakai nama netral.
class InventoryColors extends AppSurfaceColors {
  const InventoryColors(super.dark);

  factory InventoryColors.of(BuildContext context) =>
      InventoryColors(Theme.of(context).brightness == Brightness.dark);
}
