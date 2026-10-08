// lib/views/pages/laporan_panen_page.dart
import 'package:flutter/material.dart';
import '../../models/panen_model.dart';
import '../components/header.dart';
import '../components/laporan_panen_body.dart';
import '../theme/app_theme.dart';

class LaporanPanenPage extends StatelessWidget {
  final PanenItem item;

  const LaporanPanenPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const Header(titleText: 'Laporan Panen', showBackButton: true),
      backgroundColor: AppColors.canvasWarm,
      body: LaporanPanenBody(item: item),
    );
  }
}
