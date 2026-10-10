import 'package:flutter/material.dart';
import '../components/header.dart';
import '../components/panen_form_body.dart';
import '../widgets/harvest_access.dart';

class PanenFormPage extends StatelessWidget {
  const PanenFormPage({super.key, this.harvestId, this.transferId});
  final String? harvestId, transferId;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: Header(
      titleText: harvestId == null
          ? 'Tambah Hasil Panen'
          : 'Koreksi Hasil Panen',
      showBackButton: true,
      showUserIcon: false,
      toolbarHeight:
          56 + (MediaQuery.textScalerOf(context).scale(24) - 24) * 4.2,
      titleMaxLines: 3,
      useThemeColors: true,
    ),
    body: HarvestAccess(
      write: true,
      batches: harvestId == null,
      child: PanenFormBody(harvestId: harvestId, transferId: transferId),
    ),
  );
}
