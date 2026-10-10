import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/panen_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../pages/panen_form_page.dart';

class LaporanPanenBody extends ConsumerStatefulWidget {
  const LaporanPanenBody({super.key, required this.harvestId});
  final String harvestId;
  @override
  ConsumerState<LaporanPanenBody> createState() => _LaporanState();
}

class _LaporanState extends ConsumerState<LaporanPanenBody> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted &&
          (ref.read(sessionProvider).user?.permissions.contains('panen:read') ??
              false)) {
        ref.read(panenViewModelProvider.notifier).loadDetail(widget.harvestId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).user;
    if (user == null || !user.permissions.contains('panen:read')) {
      return const Text('Akses panen tidak diizinkan.');
    }
    final state = ref.watch(panenViewModelProvider);
    final detail = state.detailReads[widget.harvestId];
    final record = detail?.record;
    if (detail?.loading == true || record == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(detail?.error ?? 'Memuat laporan panen...'),
              if (detail?.error != null)
                TextButton(
                  onPressed: () => ref
                      .read(panenViewModelProvider.notifier)
                      .loadDetail(widget.harvestId),
                  child: const Text('Coba lagi'),
                ),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Panen #${record.id}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(record.date),
        const SizedBox(height: 24),
        Text(
          'Berat total: ${record.total?.wire ?? 'belum tercatat'}${record.total == null ? '' : ' kg'}',
        ),
        Text('Layak jual: ${record.saleable.wire} kg'),
        Text(
          'Reject: ${record.reject?.wire ?? 'belum tercatat'}${record.reject == null ? '' : ' kg'}',
        ),
        Text('${record.plantCount} tanaman'),
        for (final detail in record.details)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${detail.tableCode} • Meja #${detail.tableId} • Batch #${detail.transferId}',
                ),
                Text(
                  '${detail.plantCount} tanaman • Layak ${detail.saleable.wire} kg',
                ),
                Text(
                  'Total ${detail.total?.wire ?? 'belum tercatat'} • Reject ${detail.reject?.wire ?? 'belum tercatat'}',
                ),
                Text(
                  'Semai ${detail.sowingDate} • Pindah ${detail.transferDate}',
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Text('Catatan: ${record.note ?? 'Tidak ada catatan.'}'),
        if (state.refreshWarning != null) Text(state.refreshWarning!),
        if (user.permissions.contains('panen:write')) ...[
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              ref.read(panenViewModelProvider.notifier).beginDraft();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PanenFormPage(harvestId: record.id),
                ),
              );
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Koreksi Sortasi atau Catatan'),
            ),
          ),
        ],
      ],
    );
  }
}
