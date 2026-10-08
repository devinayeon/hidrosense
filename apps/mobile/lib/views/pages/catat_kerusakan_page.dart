import 'package:flutter/material.dart';
import '../../data/models/table_record.dart';
import '../../data/models/transfer_record.dart';
import '../components/form_catat_kerusakan_body.dart';
import '../components/header.dart';

class CatatKerusakanPage extends StatelessWidget {
  const CatatKerusakanPage({
    super.key,
    required this.table,
    this.initialTransfer,
  });
  final TableRecord table;
  final TransferRecord? initialTransfer;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const Header(titleText: 'Kerusakan', showBackButton: true),
    body: FormCatatKerusakanBody(
      tableId: table.id,
      tableName: table.displayName,
      initialTransfer: initialTransfer,
    ),
  );
}
