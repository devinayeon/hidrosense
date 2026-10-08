// lib/views/pages/meja_nft_page.dart
import 'package:flutter/material.dart';
import '../components/header.dart';
import '../components/meja_nft_body.dart';
import '../theme/app_theme.dart';

class MejaNftPage extends StatelessWidget {
  const MejaNftPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: Header(titleText: 'Manajemen Meja NFT', showBackButton: true),
      backgroundColor: AppColors.canvasWarm,
      body: MejaNftBody(),
    );
  }
}
