import 'package:flutter/material.dart';
import '../components/header.dart';
import '../components/laporan_panen_body.dart';
import '../widgets/harvest_access.dart';

class LaporanPanenPage extends StatelessWidget {
  const LaporanPanenPage({super.key, required this.harvestId});
  final String harvestId;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: Header(
      titleText: 'Laporan Panen',
      showBackButton: true,
      showUserIcon: false,
      toolbarHeight:
          56 + (MediaQuery.textScalerOf(context).scale(24) - 24) * 4.2,
      titleMaxLines: 3,
      useThemeColors: true,
    ),
    body: HarvestAccess(child: LaporanPanenBody(harvestId: harvestId)),
  );
}
