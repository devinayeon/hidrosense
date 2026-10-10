import 'package:flutter/material.dart';
import '../../data/models/damage_record.dart';
import '../../data/models/table_record.dart';
import '../../data/models/transfer_record.dart';
import '../components/form_catat_kerusakan_body.dart';
import '../components/header.dart';

class CatatKerusakanPage extends StatelessWidget {
  const CatatKerusakanPage({
    super.key,
    required this.table,
    this.initialTransfer,
    this.damageRecordToEdit,
  });
  final TableRecord table;
  final TransferRecord? initialTransfer;
  final DamageRecord? damageRecordToEdit;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: Header(
      toolbarHeight: MediaQuery.viewInsetsOf(context).bottom > 0
          ? 56
          : MediaQuery.textScalerOf(context).scale(21) > 30
          ? 96
          : 64,
      titleMaxLines: MediaQuery.viewInsetsOf(context).bottom > 0 ? 1 : 2,
      titleText: damageRecordToEdit != null ? 'Edit Kerusakan' : 'Kerusakan',
      showBackButton: true,
    ),
    body: FormCatatKerusakanBody(
      tableId: table.id,
      tableName: table.displayName,
      initialTransfer: initialTransfer,
      damageRecordToEdit: damageRecordToEdit,
    ),
  );
}
