import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../viewmodels/connected_table_viewmodel.dart';
import '../../../../views/v2/theme/v2_tokens.dart';
import '../../../../views/v2/widgets/v2_button.dart';
import '../../../../views/v2/widgets/v2_chip.dart';
import '../../../../views/v2/widgets/v2_icon.dart';
import '../../data/pest_models.dart';
import '../../domain/pest_summary.dart';
import '../../domain/pest_history_group.dart';
import '../viewmodels/pest_history_viewmodel.dart';
import '../widgets/decision_sheets.dart';

/// Riwayat rekomendasi dan rotasi obat. Filter status (Semua, Menunggu, Diterima, Ditolak), hama,
/// dan meja membantu melihat obat dan kelompok MoA apa yang pernah dipakai atau ditolak.
class RotationHistoryPage extends ConsumerStatefulWidget {
  const RotationHistoryPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(builder: (_) => const RotationHistoryPage());

  @override
  ConsumerState<RotationHistoryPage> createState() => _RotationHistoryPageState();
}

class _RotationHistoryPageState extends ConsumerState<RotationHistoryPage> {
  DateTime? _dari;
  DateTime? _sampai;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(pestHistoryProvider.notifier).refresh());
  }

  bool get _adaRentang => _dari != null || _sampai != null;

  String get _labelRentang {
    if (_dari != null && _sampai != null) {
      return '${labelTanggalWib(_dari!)} – ${labelTanggalWib(_sampai!)}';
    }
    if (_dari != null) return 'Dari ${labelTanggalWib(_dari!)}';
    if (_sampai != null) return 'Sampai ${labelTanggalWib(_sampai!)}';
    return 'Semua tanggal';
  }

  Future<void> _pilihRentang() async {
    final sekarang = DateTime.now();
    final hasil = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(sekarang.year + 1, 12, 31),
      initialDateRange: _dari != null && _sampai != null
          ? DateTimeRange(start: _dari!, end: _sampai!)
          : null,
      helpText: 'Pilih rentang tanggal',
    );
    if (!mounted || hasil == null) return;
    setState(() {
      _dari = hasil.start;
      _sampai = hasil.end;
    });
  }

  void _hapusRentang() => setState(() {
    _dari = null;
    _sampai = null;
  });

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
          Padding(
            padding: const EdgeInsets.fromLTRB(
              V2Space.lg,
              V2Space.md,
              V2Space.lg,
              V2Space.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: V2Space.sm,
                  runSpacing: V2Space.sm,
                  children: [
                    V2Chip(label: 'Semua', selected: state.status == null, onTap: () => notifier.setStatus(null)),
                    for (final s in RecommendationStatus.values)
                      V2Chip(label: s.label, selected: state.status == s, onTap: () => notifier.setStatus(s)),
                  ],
                ),
                const SizedBox(height: V2Space.md),
                Wrap(
                  spacing: V2Space.sm,
                  runSpacing: V2Space.sm,
                  children: [
                    V2Chip(label: 'Semua hama', selected: state.pest == null, onTap: () => notifier.setPest(null)),
                    for (final k in PestKind.values)
                      V2Chip(label: k.label, selected: state.pest == k, onTap: () => notifier.setPest(k)),
                  ],
                ),
                if (tables.isNotEmpty) ...[
                  const SizedBox(height: V2Space.md),
                  DropdownButtonFormField<String?>(
                    initialValue: state.tableId,
                    decoration: const InputDecoration(labelText: 'Meja tanam'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Semua meja')),
                      for (final t in tables) DropdownMenuItem<String?>(value: t.id, child: Text(t.code)),
                    ],
                    onChanged: notifier.setTable,
                  ),
                ],
                const SizedBox(height: V2Space.md),
                Wrap(
                  spacing: V2Space.sm,
                  runSpacing: V2Space.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    V2Button(
                      label: _labelRentang,
                      type: V2ButtonType.secondary,
                      expand: false,
                      icon: V2IconName.calendar,
                      onPressed: _pilihRentang,
                    ),
                    if (_adaRentang)
                      V2Button(
                        label: 'Hapus tanggal',
                        type: V2ButtonType.ghost,
                        expand: false,
                        onPressed: _hapusRentang,
                      ),
                  ],
                ),
              ],
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
              Text(state.error!, style: V2Type.body, textAlign: TextAlign.center),
              const SizedBox(height: V2Space.lg),
              V2Button(label: 'Coba lagi', type: V2ButtonType.secondary, onPressed: notifier.refresh),
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
    // Rentang tanggal disaring di layar (D-32); batas inklusif dan memakai
    // tanggal WIB yang sama dengan pengelompokan D-28.
    final tersaring = saringRiwayatTanggal(
      state.items,
      dari: _dari,
      sampai: _sampai,
    );
    if (tersaring.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(V2Space.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tidak ada riwayat pada rentang tanggal ini.',
                style: V2Type.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: V2Space.lg),
              V2Button(
                label: 'Hapus filter tanggal',
                type: V2ButtonType.secondary,
                onPressed: _hapusRentang,
              ),
            ],
          ),
        ),
      );
    }
    // Riwayat dikelompokkan per tanggal WIB (D-28); entri di bawah tiap header
    // tetap bisa dilipat seperti sebelumnya.
    final kelompok = kelompokkanRiwayatPerTanggal(tersaring);
    final anak = <Widget>[];
    for (final grup in kelompok) {
      anak.add(_headerTanggal(grup.label));
      for (final rec in grup.items) {
        anak.add(
          Padding(
            padding: const EdgeInsets.only(top: V2Space.md),
            child: DecidableRecommendationCard(
              key: ValueKey(rec.id),
              recommendation: rec,
              collapsible: true,
              onAccept: notifier.accept,
              onReject: notifier.reject,
              stock: stockOptions(ref),
            ),
          ),
        );
      }
    }
    if (state.error != null) {
      anak.add(
        Padding(
          padding: const EdgeInsets.only(top: V2Space.md),
          child: Text(
            state.error!,
            style: V2Type.caption,
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else if (state.hasMore) {
      anak.add(
        Padding(
          padding: const EdgeInsets.only(top: V2Space.md),
          child: V2Button(
            label: 'Muat lagi',
            type: V2ButtonType.secondary,
            state: state.loading ? V2ButtonState.loading : V2ButtonState.normal,
            onPressed: notifier.loadMore,
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView(
        padding: const EdgeInsets.all(V2Space.lg),
        children: anak,
      ),
    );
  }

  /// Header tanggal kelompok riwayat; tetap satu baris dan aman di skala 2.0.
  Widget _headerTanggal(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: V2Space.lg, bottom: V2Space.xs),
      child: Text(label, style: V2Type.bodyStrong),
    );
  }
}
