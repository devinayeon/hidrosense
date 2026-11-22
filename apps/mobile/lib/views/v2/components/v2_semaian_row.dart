import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import '../widgets/v2_badge.dart';
import '../widgets/v2_icon.dart';
import '../widgets/v2_stock_item.dart';
import 'v2_semaian_data.dart';

/// Baris semaian di dalam `Grup daftar` (frame 5.1, 5.2, 5.6).
///
/// Semua baris dipaku 80 tinggi seperti komponen `StockItem`: lead 40 berikon
/// tunas, judul nama benih, subjudul `Semai <tanggal>`, lalu HSS di kanan.
/// Semaian yang siap pindah menambah lencana hijau "Siap pindah" (frame 5.1).
///
/// Semaian selesai (frame 5.6) digambar sebagai kartu sendiri berlatar
/// `#E5E8EC` dengan ikon dan tulisan bernada `#4B5563`; ikon lead-nya memudar
/// (#6B7280 30%) sedangkan lingkarnya tetap biru muda. Bentuk itu mengikuti
/// `StockItem State=Archived` di FigCraft, bukan `V2StockItem` yang selalu
/// berlatar putih.
class V2SemaianRow extends StatelessWidget {
  const V2SemaianRow({super.key, required this.item, this.onTap});

  final V2SemaianItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (item.selesai) return _selesai();
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 80),
      child: _berjalan(),
    );
  }

  Widget _berjalan() {
    return V2StockItem(
      withCard: false,
      iconSize: 24,
      icon: V2IconName.sprout,
      title: item.nama,
      subtitle: item.labelSemai,
      quantity: item.labelHss,
      badge: item.antrean
          ? const V2Badge(label: 'Antrean', status: V2BadgeStatus.pending)
          : item.siapPindah
          ? const V2Badge(
              label: 'Siap pindah',
              status: V2BadgeStatus.success,
            )
          : null,
      onTap: onTap,
    );
  }

  /// Baris selesai: kartu `#E5E8EC` 80 tinggi dengan ikon, judul, subjudul, dan
  /// HSS bernada `#4B5563` (frame 5.6).
  Widget _selesai() {
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: V2Space.lg,
        vertical: V2Space.md,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: V2Colors.blue50,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: V2Icon(
                V2IconName.sprout,
                size: 24,
                color: V2Colors.muted.withValues(alpha: 0.3),
              ),
            ),
          ),
          const SizedBox(width: V2Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.nama,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: V2Type.bodyStrong.copyWith(color: V2Colors.slate600),
                ),
                const SizedBox(height: V2Space.xs),
                Text(
                  item.labelSemai,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: V2Type.label.copyWith(color: V2Colors.slate600),
                ),
              ],
            ),
          ),
          const SizedBox(width: V2Space.md),
          Text(
            item.labelHss,
            style: V2Type.bodyStrong.copyWith(color: V2Colors.slate600),
          ),
        ],
      ),
    );
    if (onTap == null) return _kartu(content);
    return _kartu(
      Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, child: content),
      ),
    );
  }

  Widget _kartu(Widget child) {
    return Container(
      constraints: const BoxConstraints(minHeight: 80),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: V2Colors.gray200,
        borderRadius: BorderRadius.circular(V2Radius.card),
      ),
      child: child,
    );
  }
}
