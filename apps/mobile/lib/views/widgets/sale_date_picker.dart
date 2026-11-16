import 'package:flutter/material.dart';

import '../../core/business_date.dart';
import '../theme/app_theme.dart';

/// Memilih tanggal transaksi, paling lambat hari ini (zona Asia/Jakarta).
Future<DateTime?> pickSaleDate(BuildContext context, DateTime? current) {
  final today = jakartaToday();
  return showDatePicker(
    context: context,
    initialDate: current == null || current.isAfter(today) ? today : current,
    firstDate: DateTime(2020),
    lastDate: today,
    builder: (context, child) => Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(primary: AppColors.primaryMint),
      ),
      child: child!,
    ),
  );
}
