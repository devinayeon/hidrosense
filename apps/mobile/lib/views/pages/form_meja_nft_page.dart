import 'package:flutter/material.dart';
import '../../data/models/table_record.dart';
import '../../models/meja_nft_model.dart';
import '../components/header.dart';
import '../components/form_meja_nft_body.dart';
import '../theme/app_theme.dart';

class FormMejaNftPage extends StatelessWidget {
  final TableRecord? tableRecord;
  final MejaNft? mejaItem;

  const FormMejaNftPage({
    super.key,
    this.tableRecord,
    this.mejaItem,
  });

  @override
  Widget build(BuildContext context) {
    final title = (tableRecord == null && mejaItem == null)
        ? 'Tambah Meja NFT Baru'
        : 'Edit Pengaturan Meja';

    return Scaffold(
      appBar: Header(titleText: title, showBackButton: true),
      backgroundColor: AppColors.canvasWarm,
      body: FormMejaNftBody(
        tableRecord: tableRecord,
        mejaItem: mejaItem,
      ),
    );
  }
}
