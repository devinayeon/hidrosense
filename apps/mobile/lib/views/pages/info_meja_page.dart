import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/connected_table_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../../data/models/table_record.dart';
import '../../models/meja_nft_model.dart';
import '../components/header.dart';
import '../components/info_meja_body.dart';
import '../theme/app_theme.dart';

class InfoMejaPage extends ConsumerWidget {
  final TableRecord? tableRecord;
  final MejaNft? mejaItem;

  const InfoMejaPage({super.key, this.tableRecord, this.mejaItem})
    : assert(tableRecord != null || mejaItem != null);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canRead =
        ref
            .watch(sessionProvider)
            .user
            ?.permissions
            .contains('budidaya:read') ==
        true;
    final current = canRead && tableRecord != null
        ? ref
              .watch(connectedTableProvider)
              .records
              .where((r) => r.id == tableRecord!.id)
              .firstOrNull
        : null;
    final title = canRead
        ? current?.displayName ??
              tableRecord?.displayName ??
              mejaItem?.name ??
              'Detail Meja'
        : 'Detail Meja';
    return Scaffold(
      appBar: Header(
        toolbarHeight: MediaQuery.textScalerOf(context).scale(21) > 30
            ? 96
            : 64,
        titleMaxLines: 2,
        titleText: title,
        showBackButton: true,
      ),
      backgroundColor: AppColors.canvasWarm,
      body: InfoMejaBody(tableRecord: tableRecord, mejaItem: mejaItem),
    );
  }
}
