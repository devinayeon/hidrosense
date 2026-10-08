import 'package:flutter/material.dart';
import '../../data/models/table_record.dart';
import '../../models/meja_nft_model.dart';
import '../components/header.dart';
import '../components/info_meja_body.dart';
import '../theme/app_theme.dart';

class InfoMejaPage extends StatelessWidget {
  final TableRecord? tableRecord;
  final MejaNft? mejaItem;

  const InfoMejaPage({
    super.key,
    this.tableRecord,
    this.mejaItem,
  }) : assert(tableRecord != null || mejaItem != null);

  @override
  Widget build(BuildContext context) {
    final title = tableRecord?.displayName ?? mejaItem?.name ?? 'Detail Meja';
    return Scaffold(
      appBar: Header(titleText: title, showBackButton: true),
      backgroundColor: AppColors.canvasWarm,
      body: InfoMejaBody(
        tableRecord: tableRecord,
        mejaItem: mejaItem,
      ),
    );
  }
}
