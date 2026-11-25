import 'package:flutter/material.dart';

import '../components/v2_rawat_ai_banner.dart';
import '../components/v2_rawat_data.dart';
import '../components/v2_rawat_option_row.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_action_bar.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_button.dart';
import 'v2_rawat_konfirmasi_page.dart';

/// Rekomendasi obat untuk satu hama (frame 9.19 Thrips, 9.20 Kutu daun).
///
/// Banner saran AI, lalu daftar obat dengan rotasi dari pemakaian terakhir.
/// Obat yang habis tetap tampil tetapi tidak bisa dipilih. Tombol “Pakai obat
/// ini” membawa pilihan ke halaman konfirmasi.
class V2RawatObatPage extends StatefulWidget {
  const V2RawatObatPage({
    super.key,
    required this.hama,
    required this.obat,
    required this.rotasi,
    this.onSaved,
  });

  /// Frame `9.19 Rekomendasi obat (Thrips)`.
  const V2RawatObatPage.thrips({Key? key, ValueChanged<V2RawatItem>? onSaved})
    : this(
        key: key,
        onSaved: onSaved,
        hama: designHamaThrips,
        obat: designObatThrips,
        rotasi: 'Terakhir: Sabun insektisida, 12 Nov.',
      );

  /// Frame `9.20 Rekomendasi obat (Kutu daun)`.
  const V2RawatObatPage.kutuDaun({Key? key, ValueChanged<V2RawatItem>? onSaved})
    : this(
        key: key,
        onSaved: onSaved,
        hama: designHamaKutuDaun,
        obat: designObatKutuDaun,
        rotasi: 'Terakhir untuk Kutu daun: Obat Nabati, 5 Nov.',
      );

  final V2Hama hama;
  final List<V2Obat> obat;

  /// Isi kartu “Rotasi obat”.
  final String rotasi;

  final ValueChanged<V2RawatItem>? onSaved;

  static Route<void> thripsRoute(ValueChanged<V2RawatItem>? onSaved) {
    return MaterialPageRoute<void>(
      builder: (_) => V2RawatObatPage.thrips(onSaved: onSaved),
    );
  }

  static Route<void> kutuDaunRoute(ValueChanged<V2RawatItem>? onSaved) {
    return MaterialPageRoute<void>(
      builder: (_) => V2RawatObatPage.kutuDaun(onSaved: onSaved),
    );
  }

  @override
  State<V2RawatObatPage> createState() => _V2RawatObatPageState();
}

class _V2RawatObatPageState extends State<V2RawatObatPage> {
  late V2Obat _pilih = widget.obat.first;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: V2Theme.light,
      child: Scaffold(
        backgroundColor: V2Colors.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              V2AppBar(
                title: 'Obat untuk ${widget.hama.nama}',
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    V2Space.xl,
                    V2Space.sm,
                    V2Space.xl,
                    V2Space.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const V2RawatAiBanner(),
                      const SizedBox(height: V2Space.lg),
                      Text(
                        'Pilih obat',
                        style: V2Type.label.copyWith(color: V2Colors.ink),
                      ),
                      const SizedBox(height: V2Space.sm),
                      for (
                        var index = 0;
                        index < widget.obat.length;
                        index++
                      ) ...[
                        if (index > 0) const SizedBox(height: V2Space.sm),
                        V2RawatOptionRow(
                          label: widget.obat[index].label,
                          selected: widget.obat[index].nama == _pilih.nama,
                          enabled: !widget.obat[index].habis,
                          onTap: () =>
                              setState(() => _pilih = widget.obat[index]),
                        ),
                      ],
                      const SizedBox(height: V2Space.lg),
                      _kartuRotasi(),
                    ],
                  ),
                ),
              ),
              V2ActionBar(
                actions: [
                  V2Button(
                    label: 'Pakai obat ini',
                    onPressed: () => Navigator.of(context).push(
                      V2RawatKonfirmasiPage.route(
                        hama: widget.hama,
                        obat: _pilih,
                        onSaved: widget.onSaved,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Kartu putih 120: judul “Rotasi obat” dan isi 16/24 muted.
  Widget _kartuRotasi() {
    return Container(
      height: 120,
      padding: const EdgeInsets.fromLTRB(V2Space.xl, V2Space.xl, V2Space.xl, 0),
      decoration: BoxDecoration(
        color: V2Colors.blue50,
        borderRadius: BorderRadius.circular(V2Radius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rotasi obat', style: V2Type.h2),
          const SizedBox(height: V2Space.sm),
          Text(
            widget.rotasi,
            style: V2Type.body.copyWith(color: V2Colors.muted),
          ),
        ],
      ),
    );
  }
}
