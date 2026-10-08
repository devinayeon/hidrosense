import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../components/header.dart';
import '../components/catat_penjualan_body.dart';

class CatatPenjualanPage extends ConsumerWidget {
  const CatatPenjualanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions =
        ref.watch(sessionProvider).user?.permissions ?? const <String>[];
    final allowed =
        permissions.contains('penjualan:read') &&
        permissions.contains('penjualan:write');
    return Scaffold(
      appBar: Header(
        titleText: 'Catat Penjualan',
        showBackButton: true,
        onBackPressed: () => Navigator.pop(context),
      ),
      body: allowed
          ? const CatatPenjualanBody()
          : const Center(child: Text('Akses penjualan tidak diizinkan.')),
    );
  }
}
