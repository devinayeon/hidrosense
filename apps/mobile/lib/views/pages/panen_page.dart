// lib/views/pages/panen_page.dart
import 'package:flutter/material.dart';
import '../components/header.dart';
import '../components/panen_body.dart';

class PanenPage extends StatelessWidget {
  const PanenPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: Header(titleText: 'Data Panen', showBackButton: true),
      backgroundColor: Color.fromRGBO(250, 250, 247, 1),
      body: PanenBody(),
    );
  }
}
