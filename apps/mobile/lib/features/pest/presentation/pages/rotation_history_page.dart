import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../viewmodels/connected_table_viewmodel.dart';
import '../../../../views/v2/theme/v2_tokens.dart';
import '../../../../views/v2/widgets/v2_button.dart';
import '../../../../views/v2/widgets/v2_chip.dart';
import '../../data/pest_models.dart';
import '../../domain/pest_summary.dart';
import '../viewmodels/pest_history_viewmodel.dart';
import '../widgets/decision_sheets.dart';

/// Riwayat rekomendasi dan rotasi obat. Filter status (Semua, Menunggu, Diterima, Ditolak), hama,
/// dan meja membantu melihat obat dan kelompok MoA apa yang pernah dipakai atau ditolak.
class RotationHistoryPage extends ConsumerStatefulWidget {
  const RotationHistoryPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const RotationHistoryPage());

  @override
  ConsumerState<RotationHistoryPage> createState() =>
      _RotationHistoryPageState();
}

class _RotationHistoryPageState extends ConsumerState<RotationHistoryPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(pestHistoryProvider.notifier).refresh());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pestHistoryProvider);
    final notifier = ref.read(pestHistoryProvider.notifier);
    final tables = ref.watch(connectedTableProvider).records;
    return Scaffold(
      backgroundColor: V2Colors.canvas,
      appBar: AppBar(title: const Text('Riwayat rotasi obat')),
      body: Column(
        children: [
          _ChipRow(
            children: [
              V2Chip(
                label: 'Semua',
                selected: state.status == null,
                onTap: () => notifier.setStatus(null),
              ),
              for (final s in RecommendationStatus.values)
                V2Chip(
                  label: s.label,
                  selected: state.status == s,
                  onTap: () => notifier.setStatus(s),
                ),
            ],
          ),
          _ChipRow(
            children: [
              V2Chip(
                label: 'Semua hama',
                selected: state.pest == null,
                onTap: () => notifier.setPest(null),
              ),
              for (final k in PestKind.values)
                V2Chip(
                  label: k.label,
                  selected: state.pest == k,
                  onTap: () => notifier.setPest(k),
                ),
            ],
          ),
          if (tables.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                V2Space.lg,
                0,
                V2Space.lg,
                V2Space.sm,
              ),
              child: DropdownButtonFormField<String?>(
                initialValue: state.tableId,
                decoration: const InputDecoration(labelText: 'Meja tanam'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Semua meja'),
                  ),
                  for (final t in tables)
                    DropdownMenuItem<String?>(value: t.id, child: Text(t.code)),
                ],
                onChanged: notifier.setTable,
              ),
            ),
          Expanded(child: _body(state, notifier)),
        ],
      ),
    );
  }

  Widget _body(PestHistoryState state, PestHistoryNotifier notifier) {
    if (state.items.isEmpty && state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.items.isEmpty && state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(V2Space.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.error!,
                style: V2Type.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: V2Space.lg),
              V2Button(
                label: 'Coba lagi',
                type: V2ButtonType.secondary,
                onPressed: notifier.refresh,
              ),
            ],
          ),
        ),
      );
    }
    if (state.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(V2Space.xl),
          child: Text(
            'Belum ada rekomendasi. Foto tanaman dari tab Rawat untuk mendapat saran obat.',
            style: V2Type.body,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(V2Space.lg),
        itemCount: state.items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: V2Space.md),
        itemBuilder: (context, index) {
          if (index == state.items.length) {
            if (state.error != null) {
              return Text(
                state.error!,
                style: V2Type.caption,
                textAlign: TextAlign.center,
              );
            }
            if (!state.hasMore) return const SizedBox.shrink();
            return V2Button(
              label: 'Muat lagi',
              type: V2ButtonType.secondary,
              state: state.loading
                  ? V2ButtonState.loading
                  : V2ButtonState.normal,
              onPressed: notifier.loadMore,
            );
          }
          final rec = state.items[index];
          return DecidableRecommendationCard(
            key: ValueKey(rec.id),
            recommendation: rec,
            onAccept: notifier.accept,
            onReject: notifier.reject,
            stock: stockOptions(ref),
          );
        },
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        V2Space.lg,
        V2Space.sm,
        V2Space.lg,
        V2Space.xs,
      ),
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: V2Space.sm),
            children[i],
          ],
        ],
      ),
    );
  }
}
