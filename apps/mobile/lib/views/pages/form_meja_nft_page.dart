// lib/views/pages/form_meja_nft_page.dart
import 'package:flutter/material.dart';
import '../../models/meja_nft_model.dart';
import '../components/header.dart';
import '../components/form_meja_nft_body.dart';

class FormMejaNftPage extends StatelessWidget {
  final MejaNft? mejaItem; // Jika null = Tambah, Jika ada = Edit

  const FormMejaNftPage({super.key, this.mejaItem});

  @override
  Widget build(BuildContext context) {
    final title = mejaItem == null
        ? 'Tambah Meja NFT Baru'
        : 'Edit Pengaturan Meja';

    return Scaffold(
      appBar: Header(titleText: title, showBackButton: true),
      backgroundColor: const Color.fromRGBO(250, 250, 247, 1),
      body: FormMejaNftBody(mejaItem: mejaItem),
    );
  }
}
