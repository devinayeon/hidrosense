import 'package:flutter/material.dart';
import '../../data/models/nursery_record.dart';
import 'seedling_transfer_sheet.dart';

class TransferSeedlingBottomSheet extends StatelessWidget {
  const TransferSeedlingBottomSheet({
    super.key,
    required this.sowingRecord,
    this.onSuccess,
  });

  final SowingRecord sowingRecord;
  final VoidCallback? onSuccess;

  static Future<void> show(
    BuildContext context, {
    required SowingRecord sowingRecord,
    VoidCallback? onSuccess,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => TransferSeedlingBottomSheet(
      sowingRecord: sowingRecord,
      onSuccess: onSuccess,
    ),
  );

  @override
  Widget build(BuildContext context) => SeedlingTransferSheet(
    sowingRecord: sowingRecord,
    onTransferred: onSuccess ?? () {},
  );
}
