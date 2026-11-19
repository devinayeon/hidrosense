import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import '../widgets/v2_badge.dart';
import '../widgets/v2_icon.dart';
import '../widgets/v2_list_item.dart';
import 'v2_meja_data.dart';

/// Kartu grid lubang meja tanam di halaman detail (frame 6.10, 6.11, 6.13,
/// 6.16, 6.17, 6.20).
///
/// Berbeda dari `V2GridCard` putih: kartu ini biru `#1565FF`, lubang terisi
/// lime `#A3F533`, dan lubang kosong bergaris putih 1,5. Grid selalu 294x164
/// (21 kolom x 12 baris) walau meja hanya punya 180 lubang, seperti frame 6.10.
class V2MejaGridCard extends StatelessWidget {
  const V2MejaGridCard({super.key, required this.item});

  final V2MejaItem item;

  V2BadgeStatus get _badgeStatus => switch (item.status) {
    V2MejaStatus.tersedia => V2BadgeStatus.success,
    V2MejaStatus.penuh || V2MejaStatus.perawatan => V2BadgeStatus.warning,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(V2Space.xl),
      decoration: BoxDecoration(
        color: V2Colors.blue500,
        borderRadius: BorderRadius.circular(V2Radius.sheet),
        boxShadow: V2Shadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.nama,
                  style: V2Type.bodyStrong.copyWith(color: V2Colors.white),
                ),
              ),
              const SizedBox(width: V2Space.sm),
              V2Badge(label: item.status.label, status: _badgeStatus),
            ],
          ),
          const SizedBox(height: V2Space.sm),
          Text(
            item.labelTerisi,
            style: V2Type.h2.copyWith(color: V2Colors.white),
          ),
          const SizedBox(height: V2Space.sm),
          SizedBox(
            height: 164,
            child: _LubangGrid(filled: item.terisi, total: item.jumlahLubang),
          ),
          const SizedBox(height: V2Space.sm),
          Row(
            children: [
              _Legenda(terisi: true, label: 'Terisi ${item.terisi}'),
              const SizedBox(width: V2Space.lg),
              _Legenda(terisi: false, label: 'Kosong ${item.kosong}'),
            ],
          ),
        ],
      ),
    );
  }
}

/// Grid 21 kolom, dot 10, jarak 4; terisi lime, kosong bergaris putih.
class _LubangGrid extends StatelessWidget {
  const _LubangGrid({required this.filled, required this.total});

  final int filled;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (var index = 0; index < total; index++)
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: index < filled ? V2Colors.lime400 : null,
              shape: BoxShape.circle,
              border: index < filled
                  ? null
                  : Border.all(color: V2Colors.white, width: 1.5),
            ),
          ),
      ],
    );
  }
}

class _Legenda extends StatelessWidget {
  const _Legenda({required this.terisi, required this.label});

  final bool terisi;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: terisi ? V2Colors.lime400 : null,
            shape: BoxShape.circle,
            border: terisi
                ? null
                : Border.all(color: V2Colors.white, width: 1.5),
          ),
        ),
        const SizedBox(width: V2Space.sm),
        Text(
          label,
          style: V2Type.label.copyWith(color: V2Colors.white),
        ),
      ],
    );
  }
}

/// Kartu "Tanaman di meja" (frame 6.10, 6.11, 6.13, 6.16, 6.17, 6.20).
///
/// Saat meja tersedia dan kosong kartu memakai judul "Tanaman di meja" di atas
/// isinya (6.10/6.11); saat meja penuh atau perawatan judulnya tidak digambar
/// dan hanya baris tanaman yang tampil (6.13/6.16/6.17), sama seperti frame.
class V2MejaTanamanCard extends StatelessWidget {
  const V2MejaTanamanCard({
    super.key,
    required this.item,
    this.showTitle = true,
    this.onTapTanaman,
  });

  final V2MejaItem item;
  final bool showTitle;
  final ValueChanged<V2TanamanItem>? onTapTanaman;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: V2Space.xl,
        vertical: V2Space.md,
      ),
      decoration: BoxDecoration(
        color: V2Colors.white,
        borderRadius: BorderRadius.circular(V2Radius.card),
        boxShadow: V2Shadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showTitle) ...[
            Text('Tanaman di meja', style: V2Type.h2),
            const SizedBox(height: V2Space.sm),
          ],
          if (item.tanaman.isEmpty)
            Text(
              'Belum ada tanaman di meja ini.',
              style: V2Type.body.copyWith(color: V2Colors.muted),
            )
          else
            for (var index = 0; index < item.tanaman.length; index++) ...[
              if (index > 0)
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: V2Colors.border,
                ),
              V2ListItem(
                title: item.tanaman[index].varietas,
                subtitle: item.tanaman[index].labelPanen,
                icon: V2IconName.sprout,
                onTap: onTapTanaman == null
                    ? null
                    : () => onTapTanaman!(item.tanaman[index]),
              ),
            ],
        ],
      ),
    );
  }
}