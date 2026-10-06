import 'package:flutter/material.dart';
import '../components/header.dart';
import '../components/cuaca_body.dart';

class CuacaPage extends StatelessWidget {
  const CuacaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const Header(titleText: 'Cuaca & Iklim', showBackButton: true),
      body: const CuacaBody(),
    );
  }
}
