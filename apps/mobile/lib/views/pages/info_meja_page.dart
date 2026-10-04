// lib/views/pages/info_meja_page.dart
import 'package:flutter/material.dart';
import '../../models/meja_nft_model.dart';
import '../components/header.dart';
import '../components/info_meja_body.dart';

class InfoMejaPage extends StatelessWidget {
  final MejaNft mejaItem;

  const InfoMejaPage({super.key, required this.mejaItem});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Header(titleText: mejaItem.name, showBackButton: true),
      backgroundColor: const Color.fromRGBO(250, 250, 247, 1),
      body: InfoMejaBody(mejaItem: mejaItem),
    );
  }
}
