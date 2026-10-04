// lib/views/pages/catat_kerusakan_page.dart
import 'package:flutter/material.dart';
import '../../models/baris_tanam_model.dart';
import '../../models/meja_nft_model.dart';
import '../components/form_catat_kerusakan_body.dart';
import '../components/header.dart';

class CatatKerusakanPage extends StatelessWidget {
  final MejaNft mejaItem;
  final BarisTanam? initialBaris;

  const CatatKerusakanPage({
    super.key,
    required this.mejaItem,
    this.initialBaris,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const Header(titleText: 'Catat Kerusakan', showBackButton: true),
      backgroundColor: const Color.fromRGBO(250, 250, 247, 1),
      body: FormCatatKerusakanBody(
        mejaItem: mejaItem,
        initialBaris: initialBaris,
      ),
    );
  }
}
