import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../views/v2/theme/v2_tokens.dart';
import '../../../../views/v2/widgets/v2_button.dart';
import '../../../../data/models/inventory_record.dart';
import '../../../../viewmodels/connected_inventory_viewmodel.dart';
import '../../../../viewmodels/session_viewmodel.dart';
import '../../data/pest_models.dart';
import 'recommendation_card.dart';

/// Barang inventaris aktif yang bisa dipilih sebagai bahan saat menerima.
class StockOption {
  const StockOption({required this.id, required this.name, required this.unit});

  final String id;
  final String name;
  final String unit;
}

/// Jenis inventaris yang boleh dipotong saat menerima rekomendasi (D-29).
///
/// Hanya nutrisi dan obat yang dipakai untuk perawatan; benih, media, dan
/// jenis lain tidak ditawarkan supaya stok tanam tidak ikut terpotong.
const Set<String> jenisPotongStok = <String>{'nutrisi', 'obat'};

/// `true` bila jenis inventaris boleh dipotong dari rekomendasi (D-29).
bool bolehPotongStok(String category) =>
    jenisPotongStok.contains(category.trim().toLowerCase());

/// Daftar stok yang boleh dipilih dari [records] aktif (D-29).
List<StockOption> stockOptionsDari(Iterable<InventoryRecord> records) => <StockOption>[
  for (final r in records)
    if (r.active && bolehPotongStok(r.category))
      StockOption(id: r.id, name: r.name, unit: r.unit),
];

/// Barang aktif dari inventaris yang sudah dimuat aplikasi. Kosong bila pengguna tidak boleh
/// memotong stok (backend mensyaratkan `inventaris:write`) atau belum ada sesi: provider
/// inventaris melempar galat tanpa sesi, dan itu tidak boleh meruntuhkan halaman rekomendasi.
List<StockOption> stockOptions(WidgetRef ref) {
  final permissions = ref.watch(sessionProvider.select((s) => s.user?.permissions)) ?? const <String>[];
  if (!permissions.contains('inventaris:read') || !permissions.contains('inventaris:write')) return const [];
  return stockOptionsDari(ref.watch(connectedInventoryProvider).records);
}

/// Isi lembar terima: catatan dan bahan dari stok (keduanya opsional).
typedef AcceptDecision = ({String? note, StockLineDraft? material});

/// Lembar terima. Kembali null bila dibatalkan.
Future<AcceptDecision?> showAcceptSheet(
  BuildContext context,
  PestRecommendation recommendation, {
  List<StockOption> stock = const [],
}) {
  return showModalBottomSheet<AcceptDecision>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AcceptSheet(recommendation: recommendation, stock: stock),
  );
}

class _AcceptSheet extends StatefulWidget {
  const _AcceptSheet({required this.recommendation, required this.stock});

  final PestRecommendation recommendation;
  final List<StockOption> stock;

  @override
  State<_AcceptSheet> createState() => _AcceptSheetState();
}

class _AcceptSheetState extends State<_AcceptSheet> {
  final _note = TextEditingController();
  final _amount = TextEditingController();
  StockOption? _item;

  @override
  void dispose() {
    _note.dispose();
    _amount.dispose();
    super.dispose();
  }

  /// Bahan boleh kosong; bila barang dipilih, jumlah wajib sah.
  bool get _valid => _item == null || normalizeQuantity(_amount.text) != null;

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final amountError = item != null && _amount.text.trim().isNotEmpty && normalizeQuantity(_amount.text) == null
        ? 'Isi angka lebih dari 0, paling banyak 2 desimal.'
        : null;
    return Padding(
      padding: EdgeInsets.only(
        left: V2Space.xl,
        right: V2Space.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + V2Space.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pakai ${widget.recommendation.medicine.activeIngredient}?', style: V2Type.h2),
            const SizedBox(height: V2Space.sm),
            const Text('Dicatat sebagai perawatan hari ini dan dipakai untuk rotasi berikutnya.', style: V2Type.body),
            if (widget.stock.isNotEmpty) ...[
              const SizedBox(height: V2Space.md),
              DropdownButtonFormField<String?>(
                initialValue: item?.id,
                decoration: const InputDecoration(labelText: 'Potong dari stok (opsional)'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Tidak memakai stok')),
                  for (final o in widget.stock) DropdownMenuItem<String?>(value: o.id, child: Text('${o.name} (${o.unit})')),
                ],
                onChanged: (id) => setState(() {
                  _item = id == null ? null : widget.stock.firstWhere((o) => o.id == id);
                }),
              ),
              if (item != null)
                TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: 'Jumlah (${item.unit})', errorText: amountError),
                ),
            ] else ...[
              const SizedBox(height: V2Space.md),
              // Bila tidak ada stok nutrisi/obat, jelaskan kenapa pilihan potong
              // stok tidak muncul alih-alih diam saja (D-29).
              const Text(
                'Belum ada stok nutrisi atau obat yang bisa dipotong.',
                style: V2Type.caption,
              ),
            ],
            TextField(
              controller: _note,
              maxLength: 500,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
            ),
            const SizedBox(height: V2Space.md),
            V2Button(
              label: 'Terima',
              expand: true,
              state: _valid ? V2ButtonState.normal : V2ButtonState.disabled,
              onPressed: _valid
                  ? () {
                      final note = _note.text.trim();
                      final chosen = _item;
                      Navigator.of(context).pop((
                        note: note.isEmpty ? null : note,
                        material: chosen == null
                            ? null
                            : StockLineDraft(inventoryId: chosen.id, amount: normalizeQuantity(_amount.text)!, unit: chosen.unit),
                      ));
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu rekomendasi yang membuka lembar terima/tolak lalu memanggil ViewModel.
///
/// Konsumer Riverpod karena "Terima" dengan potong stok mengubah saldo di server:
/// daftar stok, kartu "Stok menipis" di Beranda dan detail barang membaca
/// `connectedInventoryProvider`, jadi provider itu harus dimuat ulang supaya
/// angkanya tidak tertinggal (BUG-23).
class DecidableRecommendationCard extends ConsumerWidget {
  const DecidableRecommendationCard({
    super.key,
    required this.recommendation,
    required this.onAccept,
    required this.onReject,
    this.stock = const [],
    this.collapsible = false,
  });

  final PestRecommendation recommendation;
  final Future<String?> Function(String id, {String? note, List<StockLineDraft> materials}) onAccept;
  final List<StockOption> stock;
  final Future<String?> Function(String id, RejectReason reason, {String? note}) onReject;

  /// Teruskan ke [RecommendationCard]: ringkasan yang bisa dibuka (BUG-32).
  final bool collapsible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = recommendation.id;
    return RecommendationCard(
      recommendation: recommendation,
      collapsible: collapsible,
      onAccept: () async {
        final decision = await showAcceptSheet(context, recommendation, stock: stock);
        if (decision == null) return null;
        final material = decision.material;
        final error = await onAccept(id, note: decision.note, materials: material == null ? const [] : [material]);
        // Sukses + ada bahan = saldo berkurang di server; muat ulang daftar/saldo.
        if (error == null && material != null) {
          ref.invalidate(connectedInventoryProvider);
        }
        return error;
      },
      onReject: () async {
        final picked = await showRejectSheet(context);
        if (picked == null) return null;
        return onReject(id, picked.reason, note: picked.note);
      },
    );
  }
}

/// Lembar alasan penolakan. Kembali null bila dibatalkan.
Future<({RejectReason reason, String? note})?> showRejectSheet(BuildContext context) {
  return showModalBottomSheet<({RejectReason reason, String? note})>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _RejectSheet(),
  );
}

class _RejectSheet extends StatefulWidget {
  const _RejectSheet();

  @override
  State<_RejectSheet> createState() => _RejectSheetState();
}

class _RejectSheetState extends State<_RejectSheet> {
  RejectReason? _reason;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _valid {
    final reason = _reason;
    if (reason == null) return false;
    return !reason.requiresNote || _note.text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: V2Space.xl,
        right: V2Space.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + V2Space.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kenapa ditolak?', style: V2Type.h2),
            const SizedBox(height: V2Space.sm),
            RadioGroup<RejectReason>(
              groupValue: _reason,
              onChanged: (value) => setState(() => _reason = value),
              child: Column(
                children: [
                  for (final reason in RejectReason.values)
                    RadioListTile<RejectReason>(
                      contentPadding: EdgeInsets.zero,
                      title: Text(reason.label, style: V2Type.body),
                      value: reason,
                    ),
                ],
              ),
            ),
            TextField(
              controller: _note,
              maxLength: 500,
              minLines: 1,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: _reason?.requiresNote == true ? 'Catatan (wajib)' : 'Catatan (opsional)',
              ),
            ),
            const SizedBox(height: V2Space.md),
            V2Button(
              label: 'Kirim alasan',
              expand: true,
              state: _valid ? V2ButtonState.normal : V2ButtonState.disabled,
              onPressed: _valid
                  ? () {
                      final note = _note.text.trim();
                      Navigator.of(context).pop((reason: _reason!, note: note.isEmpty ? null : note));
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
