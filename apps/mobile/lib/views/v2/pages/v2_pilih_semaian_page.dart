import 'package:flutter/material.dart';

import '../components/v2_semaian_assets.dart';
import '../components/v2_semaian_data.dart';
import '../components/v2_semaian_row.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_action_bar.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_group_list.dart';

/// Halaman "Pilih semaian" saat menambah tanaman ke meja (frame 6.14/6.15).
///
/// Hanya semaian yang sudah HSS 15 (siap pindah) yang ditawarkan. Tanpa
/// semaian siap, halaman menampilkan ilustrasi dan tombol "Lihat semaian" yang
/// membawa pengguna ke daftar semaian.
class V2PilihSemaianPage extends StatelessWidget {
  const V2PilihSemaianPage({super.key, this.items, this.onLihatSemaian});

  /// Frame `6.14 Pilih semaian`: satu Romaine HSS 17.
  const V2PilihSemaianPage.siap({super.key})
    : items = null,
      onLihatSemaian = null;

  /// Frame `6.15 Belum ada semaian siap`.
  const V2PilihSemaianPage.kosong({super.key})
    : items = const <V2SemaianItem>[],
      onLihatSemaian = null;

  /// Semaian yang ditampilkan; null berarti data contoh siap pindah.
  final List<V2SemaianItem>? items;
  final VoidCallback? onLihatSemaian;

  static Route<V2SemaianItem> route() {
    return MaterialPageRoute<V2SemaianItem>(
      builder: (_) => const V2PilihSemaianPage(),
    );
  }

  List<V2SemaianItem> get _siap =>
      (items ?? designSemaian).where((item) => item.siapPindah).toList();

  @override
  Widget build(BuildContext context) {
    final siap = _siap;
    final kosong = siap.isEmpty;

    return Theme(
      data: V2Theme.light,
      child: Scaffold(
        backgroundColor: V2Colors.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              V2AppBar(
                title: 'Pilih semaian',
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    V2Space.xl,
                    V2Space.sm,
                    V2Space.xl,
                    V2Space.lg,
                  ),
                  child: kosong ? _kosong() : _daftar(context, siap),
                ),
              ),
              if (kosong)
                V2ActionBar(
                  actions: [
                    V2Button(
                      label: 'Lihat semaian',
                      onPressed:
                          onLihatSemaian ?? () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _daftar(BuildContext context, List<V2SemaianItem> siap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Hanya semaian HSS 15 atau lebih.',
          style: V2Type.label.copyWith(color: V2Colors.muted),
        ),
        const SizedBox(height: V2Space.lg),
        V2GroupList(
          children: [
            for (final item in siap)
              V2SemaianRow(
                item: item,
                onTap: () => Navigator.of(context).pop(item),
              ),
          ],
        ),
      ],
    );
  }

  /// Ilustrasi 160 di y185, judul di y361, isi di y413 (frame 6.15).
  Widget _kosong() {
    return Column(
      children: [
        const SizedBox(height: 177),
        Image.asset(V2SemaianAssets.nurserySeedlings, width: 160, height: 160),
        const SizedBox(height: V2Space.lg),
        Text(
          'Belum ada yang siap',
          textAlign: TextAlign.center,
          style: V2Type.h1,
        ),
        const SizedBox(height: V2Space.lg),
        Text(
          'Semaian siap pindah di HSS 15.',
          textAlign: TextAlign.center,
          style: V2Type.body.copyWith(color: V2Colors.muted),
        ),
      ],
    );
  }
}
