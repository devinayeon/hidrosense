import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import '../widgets/v2_badge.dart';
import '../widgets/v2_icon.dart';
import '../widgets/v2_list_item.dart';
import '../widgets/v2_skeleton.dart';
import 'v2_meja_data.dart';

/// Kartu grid lubang meja tanam di halaman detail (frame 6.10, 6.11, 6.13,
/// 6.16, 6.17, 6.20).
///
/// Berbeda dari `V2GridCard` putih: kartu ini biru `#1565FF`, lubang terisi
/// lime `#A3F533`, dan lubang kosong bergaris putih 1,5. Grid membungkus sendiri
/// sesuai jumlah lubang; sebelumnya dipaku 294x164 sehingga grid besar terpotong
/// pada skala teks besar (BUG-24).
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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: V2Space.sm,
            runSpacing: V2Space.xs,
            children: [
              Text(
                item.nama,
                style: V2Type.bodyStrong.copyWith(color: V2Colors.white),
              ),
              V2Badge(label: item.status.label, status: _badgeStatus),
            ],
          ),
          const SizedBox(height: V2Space.sm),
          Text(
            item.labelTerisi,
            style: V2Type.h2.copyWith(color: V2Colors.white),
          ),
          const SizedBox(height: V2Space.sm),
          // Tanpa tinggi tetap: jumlah lubang menentukan tinggi grid, dan pada
          // skala teks besar legenda ikut membungkus (BUG-24).
          _LubangGrid(filled: item.terisi, total: item.jumlahLubang),
          const SizedBox(height: V2Space.sm),
          Wrap(
            spacing: V2Space.lg,
            runSpacing: V2Space.xs,
            children: [
              _Legenda(terisi: true, label: 'Terisi ${item.terisi}'),
              _Legenda(terisi: false, label: 'Kosong ${item.kosong}'),
            ],
          ),
        ],
      ),
    );
  }
}

/// Grid 21 kolom, dot 10, jarak 4; terisi lime, kosong bergaris putih. Grid
/// juga dipakai sebagai penanda "indikator lubang" (BUG-24).
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
        // Teks legenda di kartu biru boleh membungkus, bukan meluber (BUG-24).
        Flexible(
          child: Text(
            label,
            style: V2Type.label.copyWith(color: V2Colors.white),
          ),
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
///
/// Saat [loading] kartu menampilkan kerangka pemuatan, bukan pesan "Belum ada
/// tanaman": daftar yang kosong karena data belum datang tidak sama dengan meja
/// yang benar-benar kosong.
class V2MejaTanamanCard extends StatelessWidget {
  const V2MejaTanamanCard({
    super.key,
    required this.item,
    this.showTitle = true,
    this.loading = false,
    this.onTapTanaman,
  });

  final V2MejaItem item;
  final bool showTitle;

  /// Pemindahan/penyemaian masih dimuat dari server.
  final bool loading;

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
          if (loading)
            const _TanamanSkeleton()
          else if (item.tanaman.isEmpty)
            Text(
              'Belum ada tanaman di meja ini.',
              style: V2Type.body.copyWith(color: V2Colors.muted),
            )
          else
            for (var index = 0; index < item.tanaman.length; index++) ...[
              if (index > 0)
                const Divider(height: 1, thickness: 1, color: V2Colors.border),
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

/// Kerangka dua baris tanaman; bentuknya mengikuti [V2ListItem] (lingkaran 48
/// dan dua garis teks) supaya ruang yang dipesan sama dengan isi aslinya.
class _TanamanSkeleton extends StatelessWidget {
  const _TanamanSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Memuat tanaman di meja',
      container: true,
      child: ExcludeSemantics(
        child: Column(
          children: [
            for (var index = 0; index < 2; index++) ...[
              if (index > 0)
                const Divider(height: 1, thickness: 1, color: V2Colors.border),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: V2Space.sm),
                child: Row(
                  children: [
                    const V2Skeleton.circle(size: 48),
                    const SizedBox(width: V2Space.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 140),
                            child: const V2Skeleton.line(
                              width: double.infinity,
                            ),
                          ),
                          const SizedBox(height: V2Space.sm),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 96),
                            child: const V2Skeleton.line(
                              width: double.infinity,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
