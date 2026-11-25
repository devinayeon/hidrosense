import 'package:flutter/material.dart';

import '../../../../views/v2/theme/v2_tokens.dart';
import '../../../../views/v2/widgets/v2_button.dart';
import '../../../../views/v2/widgets/v2_card.dart';
import '../../data/pest_models.dart';

const List<String> _bulan = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

/// `2026-09-30` → `30 Sep 2026`. Nilai yang bukan tanggal ditampilkan apa adanya.
String formatAppliedDate(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.day} ${_bulan[d.month - 1]} ${d.year}';
}

String moaLine(Medicine m) {
  if (m.moaCode == null) return 'Tanpa kelompok MoA';
  return 'MoA ${m.moaCode}${m.moaName == null ? '' : ' · ${m.moaName}'}';
}

/// Ringkasan tanggal untuk keadaan kartu tertutup: tanggal pakai bila sudah
/// diterima, atau tanggal rekomendasi dibuat.
String ringkasTanggalRekomendasi(PestRecommendation r) {
  final applied = r.appliedOn;
  if (applied != null) return 'Dipakai ${formatAppliedDate(applied)}';
  return 'Dicatat ${formatAppliedDate(r.createdAt.toIso8601String())}';
}

/// Kartu satu rekomendasi obat. Menampilkan alasan, kelompok MoA, sumber, dan peringatan data
/// yang belum diverifikasi, karena saran kimia salah berisiko bagi tanaman dan konsumen.
class RecommendationCard extends StatefulWidget {
  const RecommendationCard({
    super.key,
    required this.recommendation,
    this.onAccept,
    this.onReject,
    this.collapsible = false,
  });

  final PestRecommendation recommendation;

  /// Mengembalikan pesan galat, atau null bila berhasil.
  final Future<String?> Function()? onAccept;
  final Future<String?> Function()? onReject;

  /// Bila true, rincian disembunyikan di balik ringkasan 1–2 baris yang bisa
  /// dibuka. Dipakai daftar riwayat rotasi supaya daftar tidak terlalu panjang
  /// (BUG-32); kartu tunggal tetap tampil penuh.
  final bool collapsible;

  @override
  State<RecommendationCard> createState() => _RecommendationCardState();
}

class _RecommendationCardState extends State<RecommendationCard> {
  bool _busy = false;
  late bool _expanded = !widget.collapsible;

  Future<void> _run(Future<String?> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final error = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.recommendation;
    final m = r.medicine;
    final pending = r.status == RecommendationStatus.menunggu;
    final showDetail = !widget.collapsible || _expanded;
    return V2Card(
      padding: const EdgeInsets.all(V2Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${r.pest.label} · meja ${r.tableCode}',
                  style: V2Type.label,
                ),
              ),
              _StatusTag(status: r.status),
            ],
          ),
          const SizedBox(height: V2Space.sm),
          if (!showDetail) ...[
            Text(
              '${m.activeIngredient} · ${moaLine(m)}',
              style: V2Type.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: V2Space.xs),
            Text(ringkasTanggalRekomendasi(r), style: V2Type.caption),
          ],
          if (showDetail) ...[
          Text(m.activeIngredient, style: V2Type.h2),
          const SizedBox(height: V2Space.xs),
          Text(moaLine(m), style: V2Type.caption),
          const SizedBox(height: V2Space.md),
          Text(r.reason, style: V2Type.body),
          if (m.note != null) ...[
            const SizedBox(height: V2Space.sm),
            Text(m.note!, style: V2Type.caption),
          ],
          if (m.kind == MedicineKind.kimia) ...[
            const SizedBox(height: V2Space.sm),
            Text(
              m.preHarvestDays == null
                  ? 'Masa tunggu panen: cek label produk.'
                  : 'Masa tunggu panen minimal ${m.preHarvestDays} hari.',
              style: V2Type.bodyStrong,
            ),
            if (m.preHarvestSource != null)
              Text(
                '${m.preHarvestSource}. Ikuti label produk Anda bila berbeda.',
                style: V2Type.caption,
              ),
          ],
          if (!m.verified) ...[
            const SizedBox(height: V2Space.sm),
            Container(
              padding: const EdgeInsets.all(V2Space.md),
              decoration: BoxDecoration(
                color: V2Colors.amber100,
                borderRadius: BorderRadius.circular(V2Radius.iconBox),
              ),
              child: Text(
                'Data obat belum diverifikasi pakar. Pastikan produk terdaftar untuk selada dan ikuti label sebelum memakai.',
                style: V2Type.caption.copyWith(color: V2Colors.amber800),
              ),
            ),
          ],
          const SizedBox(height: V2Space.sm),
          Text('Sumber: ${m.source}', style: V2Type.caption),
          if (r.status == RecommendationStatus.diterima &&
              r.appliedOn != null) ...[
            const SizedBox(height: V2Space.sm),
            Text(
              'Dipakai ${formatAppliedDate(r.appliedOn!)}',
              style: V2Type.bodyStrong,
            ),
            for (final m in r.materials)
              Text(
                'Stok terpakai: ${m.name} ${m.amount} ${m.unit}',
                style: V2Type.caption,
              ),
            if (r.careNote != null) Text(r.careNote!, style: V2Type.caption),
          ],
          if (r.status == RecommendationStatus.ditolak) ...[
            const SizedBox(height: V2Space.sm),
            Text(
              'Alasan: ${r.rejectionReason?.label ?? 'tidak dicatat'}',
              style: V2Type.bodyStrong,
            ),
            if (r.rejectionNote != null)
              Text(r.rejectionNote!, style: V2Type.caption),
          ],
          if (pending &&
              (widget.onAccept != null || widget.onReject != null)) ...[
            const SizedBox(height: V2Space.lg),
            Row(
              children: [
                Expanded(
                  child: V2Button(
                    label: 'Tolak',
                    type: V2ButtonType.secondary,
                    state: _busy
                        ? V2ButtonState.disabled
                        : V2ButtonState.normal,
                    onPressed: widget.onReject == null
                        ? null
                        : () => _run(widget.onReject!),
                  ),
                ),
                const SizedBox(width: V2Space.md),
                Expanded(
                  child: V2Button(
                    label: 'Terima',
                    state: _busy ? V2ButtonState.loading : V2ButtonState.normal,
                    onPressed: widget.onAccept == null
                        ? null
                        : () => _run(widget.onAccept!),
                  ),
                ),
              ],
            ),
          ],
          ],
          if (widget.collapsible)
            _ExpandToggle(
              expanded: _expanded,
              onTap: () => setState(() => _expanded = !_expanded),
            ),
        ],
      ),
    );
  }
}

/// Tombol buka/tutup rincian kartu. Label teks + ikon (bukan warna saja) dan
/// tinggi sentuh minimal 48 dp.
class _ExpandToggle extends StatelessWidget {
  const _ExpandToggle({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(V2Radius.iconBox),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: V2Space.sm,
              horizontal: V2Space.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    expanded ? 'Sembunyikan detail' : 'Lihat detail',
                    softWrap: true,
                    style: V2Type.label.copyWith(color: V2Colors.blue700),
                  ),
                ),
                const SizedBox(width: V2Space.xs),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: V2Colors.blue700,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.status});

  final RecommendationStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      RecommendationStatus.menunggu => (V2Colors.amber100, V2Colors.amber800),
      RecommendationStatus.diterima => (V2Colors.green100, V2Colors.green700),
      RecommendationStatus.ditolak => (V2Colors.red100, V2Colors.red700),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: V2Space.md,
        vertical: V2Space.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(V2Radius.pill),
      ),
      child: Text(
        status.label,
        style: V2Type.caption.copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}
