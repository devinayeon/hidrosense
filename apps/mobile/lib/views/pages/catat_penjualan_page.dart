import 'package:flutter/material.dart';
import '../components/header.dart';
import '../components/catat_penjualan_body.dart';

class CatatPenjualanPage extends StatelessWidget {
  const CatatPenjualanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Header(
        titleText: 'Catat Penjualan',
        showBackButton: true,
        onBackPressed: () => Navigator.pop(context),
      ),
      body: const CatatPenjualanBody(),
    );
  }
}
