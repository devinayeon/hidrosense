import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/penjualan_model.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../components/header.dart';
import '../components/catat_penjualan_body.dart';

class CatatPenjualanPage extends ConsumerWidget {
  final PenjualanItem? itemToEdit;

  const CatatPenjualanPage({super.key, this.itemToEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions =
        ref.watch(sessionProvider).user?.permissions ?? const <String>[];
    final allowed =
        permissions.contains('penjualan:read') &&
        permissions.contains('penjualan:write');
    final isEdit = itemToEdit != null;

    return Scaffold(
      appBar: Header(
        titleText: isEdit ? 'Edit Penjualan' : 'Catat Penjualan',
        showBackButton: true,
        onBackPressed: () => Navigator.pop(context),
      ),
      body: allowed
          ? CatatPenjualanBody(itemToEdit: itemToEdit)
          : const Center(child: Text('Akses penjualan tidak diizinkan.')),
    );
  }
}
