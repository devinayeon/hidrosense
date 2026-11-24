import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_icon.dart';
import 'v2_cuaca_assets.dart';
import 'v2_cuaca_data.dart';

/// Nama lokasi + waktu pembaruan di atas segmen (10.1–10.5, 10.8–10.11).
///
/// Baris nama setinggi 48 dengan chevron 24 tepat di kanan teks; menyentuhnya
/// membuka sheet pilih lokasi (10.5).
class V2CuacaLokasiHeader extends StatelessWidget {
  const V2CuacaLokasiHeader({
    super.key,
    required this.lokasi,
    required this.caption,
    this.onTap,
  });

  final String lokasi;
  final String caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            lokasi,
            style: V2Type.bodyStrong,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: V2Space.xs),
        const V2Icon(V2IconName.chevronDown),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tinggi minimum 48 (bukan tetap): nama lokasi boleh membungkus dan
        // baris ikut tinggi saat skala teks sistem besar (BUG-20).
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: onTap == null
              ? label
              : Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(V2Radius.sm),
                    child: label,
                  ),
                ),
        ),
        Text(
          caption,
          style: V2Type.label.copyWith(color: V2Colors.muted),
        ),
      ],
    );
  }
}

/// Kartu “Sekarang” 342×144: ilustrasi 96 lalu suhu dan kondisi (10.1/10.5/10.8).
class V2CuacaSekarangCard extends StatelessWidget {
  const V2CuacaSekarangCard({
    super.key,
    this.data = designCuacaSekarang,
  });

  final V2CuacaSekarang data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(V2Space.xl),
      decoration: BoxDecoration(
        color: V2Colors.white,
        borderRadius: BorderRadius.circular(V2Radius.card),
        boxShadow: V2Shadow.card,
      ),
      child: Row(
        children: [
          Image.asset(
            V2CuacaAssets.weatherGreenhouse,
            width: 96,
            height: 96,
            filterQuality: FilterQuality.high,
          ),
          const SizedBox(width: V2Space.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(data.suhu, style: V2Type.display),
                const SizedBox(height: V2Space.xs),
                Text(data.kondisi, style: V2Type.bodyStrong),
                const SizedBox(height: V2Space.xs),
                Text(
                  data.catatan,
                  style: V2Type.label.copyWith(color: V2Colors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu info 342×128 berisi tiga baris label dan nilai (10.1/10.5/10.8).
class V2CuacaInfoCard extends StatelessWidget {
  const V2CuacaInfoCard({super.key, this.data = designCuacaSekarang});

  final V2CuacaSekarang data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: V2Space.xl,
        vertical: V2Space.lg,
      ),
      decoration: BoxDecoration(
        color: V2Colors.white,
        borderRadius: BorderRadius.circular(V2Radius.card),
        boxShadow: V2Shadow.card,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _InfoRow(label: 'Kelembapan', value: data.kelembapan),
          const SizedBox(height: V2Space.md),
          _InfoRow(label: 'Angin', value: data.angin),
          const SizedBox(height: V2Space.md),
          _InfoRow(label: 'Hujan', value: data.hujan),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kedua sisi fleksibel: label panjang atau nilai panjang membungkus
        // alih-alih meluber saat skala teks sistem besar (BUG-20).
        Expanded(
          child: Text(
            label,
            style: V2Type.label.copyWith(color: V2Colors.muted),
          ),
        ),
        const SizedBox(width: V2Space.sm),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: V2Type.bodyStrong,
          ),
        ),
      ],
    );
  }
}

/// Kartu saran 342×116/140: judul, isi, lalu dasar saran (10.3).
class V2CuacaSaranCard extends StatelessWidget {
  const V2CuacaSaranCard({super.key, required this.saran});

  final V2CuacaSaran saran;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: V2Space.xl,
        vertical: V2Space.lg,
      ),
      decoration: BoxDecoration(
        color: V2Colors.white,
        borderRadius: BorderRadius.circular(V2Radius.card),
        boxShadow: V2Shadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(saran.judul, style: V2Type.bodyStrong),
          const SizedBox(height: V2Space.sm),
          Text(saran.isi, style: V2Type.body),
          const SizedBox(height: V2Space.sm),
          Text(
            saran.dasar,
            style: V2Type.label.copyWith(color: V2Colors.muted),
          ),
        ],
      ),
    );
  }
}

/// Kartu catatan saran: kosong (10.4), butuh internet (10.10), gagal (10.11).
class V2CuacaCatatanCard extends StatelessWidget {
  const V2CuacaCatatanCard({
    super.key,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(V2Space.xl),
      decoration: BoxDecoration(
        color: V2Colors.white,
        borderRadius: BorderRadius.circular(V2Radius.card),
        boxShadow: V2Shadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: V2Type.bodyStrong),
          const SizedBox(height: V2Space.sm),
          Text(
            body,
            style: V2Type.body.copyWith(color: V2Colors.muted),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: V2Space.sm),
            V2Button(
              label: actionLabel!,
              type: V2ButtonType.secondary,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}