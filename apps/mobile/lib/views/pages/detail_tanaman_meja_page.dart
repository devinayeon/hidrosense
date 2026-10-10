import 'package:flutter/material.dart';
import '../../data/models/table_record.dart';
import '../components/detail_tanaman_meja_body.dart';
import '../components/header.dart';

class DetailTanamanMejaPage extends StatelessWidget {
  const DetailTanamanMejaPage({super.key, required this.table});
  final TableRecord table;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: Header(
      toolbarHeight: MediaQuery.textScalerOf(context).scale(21) > 30 ? 96 : 64,
      titleMaxLines: 2,
      titleText: 'Batch ${table.displayName}',
      showBackButton: true,
    ),
    body: DetailTanamanMejaBody(table: table),
  );
}
