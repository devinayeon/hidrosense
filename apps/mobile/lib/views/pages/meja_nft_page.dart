// lib/views/pages/meja_nft_page.dart
import 'package:flutter/material.dart';
import '../components/header.dart';
import '../components/meja_nft_body.dart';
import '../theme/app_theme.dart';

class MejaNftPage extends StatelessWidget {
  const MejaNftPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Header(
        titleText: 'Manajemen Meja NFT',
        showBackButton: true,
        toolbarHeight: MediaQuery.textScalerOf(context).scale(21) > 30
            ? 96
            : 64,
        titleMaxLines: 2,
      ),
      backgroundColor: AppColors.canvasWarm,
      body: const MejaNftBody(),
    );
  }
}
