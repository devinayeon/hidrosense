import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../components/header.dart';
import '../components/penjualan_body.dart';

class PenjualanPage extends ConsumerWidget {
  const PenjualanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allowed =
        ref
            .watch(sessionProvider)
            .user
            ?.permissions
            .contains('penjualan:read') ??
        false;
    return Scaffold(
      appBar: Header(
        titleText: 'Penjualan',
        showBackButton: true,
        onBackPressed: () => Navigator.pop(context),
      ),
      body: allowed
          ? const PenjualanBody()
          : const Center(child: Text('Akses penjualan tidak diizinkan.')),
    );
  }
}
