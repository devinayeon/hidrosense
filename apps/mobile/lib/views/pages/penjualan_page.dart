import 'package:flutter/material.dart';
import '../components/header.dart';
import '../components/penjualan_body.dart';

class PenjualanPage extends StatelessWidget {
  const PenjualanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Header(
        titleText: 'Penjualan',
        showBackButton: true,
        onBackPressed: () => Navigator.pop(context),
      ),
      body: const PenjualanBody(),
    );
  }
}
