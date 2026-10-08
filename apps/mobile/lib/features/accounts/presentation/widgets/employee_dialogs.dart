import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../views/theme/app_theme.dart';
import '../../data/models/employee_model.dart';

class EmployeeDialogs {
  static Future<bool> confirmDeactivation(
    BuildContext context,
    EmployeeModel employee,
  ) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Nonaktifkan Pegawai?'),
        content: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text(
            'Akun ${employee.nama} (@${employee.username}) tidak akan dapat mengakses aplikasi. Sesi aktif akan segera dicabut.',
            style: const TextStyle(fontSize: 13),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Nonaktifkan'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static Future<bool> confirmActivation(
    BuildContext context,
    EmployeeModel employee,
  ) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Aktifkan Kembali Akun?'),
        content: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text(
            'Pegawai ${employee.nama} (@${employee.username}) akan dapat kembali masuk ke aplikasi HidroSense.',
            style: const TextStyle(fontSize: 13),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Aktifkan',
              style: TextStyle(color: AppColors.primaryDarkTeal),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
