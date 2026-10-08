// lib/views/pages/panen_page.dart
import 'package:flutter/material.dart';
import '../components/header.dart';
import '../components/panen_body.dart';
import '../theme/app_theme.dart';

class PanenPage extends StatelessWidget {
  const PanenPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: Header(titleText: 'Data Panen', showBackButton: true),
      backgroundColor: AppColors.canvasWarm,
      body: PanenBody(),
    );
  }
}
