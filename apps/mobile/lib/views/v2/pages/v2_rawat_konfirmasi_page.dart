import 'package:flutter/material.dart';

import '../components/v2_rawat_data.dart';
import '../components/v2_rawat_option_row.dart';
import '../components/v2_semaian_date_sheet.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_action_bar.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_bottom_sheet.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_dialog.dart';
import '../widgets/v2_icon.dart';
import '../widgets/v2_select_field.dart';
import '../widgets/v2_stepper.dart';
import 'v2_rawat_detail_page.dart';

const List<String> _pilihanTanamanKonfirmasi = <String>[
  'Meja A2, Romaine',
  'Meja A3, Butterhead',
];

/// Form konfirmasi perawatan (frame 9.21), stok obat kurang (9.22), dan
/// dialog buang perubahan (9.28).
///
/// Tanggal memakai sheet kalender 5.8, tanaman dan obat memilih lewat sheet
/// seperti 7.9. Jumlah obat dibatasi stok; bila melebihi, isian bergalat dan
/// kartu “Stok berkurang” disembunyikan (9.22). Kembali saat sudah ada
/// perubahan memunculkan dialog 9.28.
class V2RawatKonfirmasiPage extends StatefulWidget {
  const V2RawatKonfirmasiPage({
    super.key,
    this.hama = designHamaThrips,
    this.obat = designObatNabati,
    this.previewStokKurang = false,
    this.previewBuang = false,
    this.onSaved,
  });

  /// Frame `9.21 Konfirmasi perawatan`: 1 botol Obat Nabati.
  const V2RawatKonfirmasiPage.biasa({Key? key})
    : this(key: key);

  /// Frame `9.22 Stok obat kurang`: 2 botol, stok hanya 1.
  const V2RawatKonfirmasiPage.stokKurang({Key? key})
    : this(key: key, previewStokKurang: true);

  /// Frame `9.28 Buang perubahan`: dialog di atas form.
  const V2RawatKonfirmasiPage.buang({Key? key})
    : this(key: key, previewBuang: true);

  final V2Hama hama;
  final V2Obat obat;
  final bool previewStokKurang;
  final bool previewBuang;
  final ValueChanged<V2RawatItem>? onSaved;

  static Route<void> route({
    required V2Hama hama,
    required V2Obat obat,
    ValueChanged<V2RawatItem>? onSaved,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => V2RawatKonfirmasiPage(
        hama: hama,
        obat: obat,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<V2RawatKonfirmasiPage> createState() => _V2RawatKonfirmasiPageState();
}

class _V2RawatKonfirmasiPageState extends State<V2RawatKonfirmasiPage> {
  late DateTime _tanggal = v2RawatHariIni;
  String _tanaman = _pilihanTanamanKonfirmasi.first;
  late V2Obat _obat = widget.obat;
  late int _jumlah = widget.previewStokKurang ? 2 : 1;
  late bool _berubah = widget.previewStokKurang;
  late bool _dialog = widget.previewBuang;

  bool get _stokKurang => _jumlah > _obat.stok;

  /// Ketik langsung jumlah botol, atau lewat minus/plus (BUG-37).
  void _setJumlah(int value) {
    if (value < 1) return;
    setState(() {
      _jumlah = value;
      _berubah = true;
    });
  }

  Future<void> _pilihTanggal() async {
    final hasil = await showV2SemaianDateSheet(
      context,
      selected: _tanggal,
    );
    if (!mounted || hasil == null) return;
    setState(() {
      _tanggal = hasil;
      _berubah = true;
    });
  }

  Future<void> _pilihTanaman() async {
    final hasil = await _pilihSheet(
      title: 'Pilih tanaman',
      pilihan: _pilihanTanamanKonfirmasi,
      terpilih: _tanaman,
    );
    if (!mounted || hasil == null) return;
    setState(() {
      _tanaman = hasil;
      _berubah = true;
    });
  }

  Future<void> _pilihObat() async {
    final hasil = await _pilihSheet(
      title: 'Pilih obat',
      pilihan: <String>[
        for (final item in designObatThrips)
          if (!item.habis) item.nama,
      ],
      terpilih: _obat.nama,
    );
    if (!mounted || hasil == null) return;
    setState(() {
      _obat = designObatThrips.firstWhere((item) => item.nama == hasil);
      _berubah = true;
    });
  }

  Future<String?> _pilihSheet({
    required String title,
    required List<String> pilihan,
    required String terpilih,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: V2Colors.ink.withValues(alpha: 0.6),
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          var draft = terpilih;
          return V2BottomSheet(
            title: title,
            actions: V2Button(
              label: 'Pilih',
              onPressed: () => Navigator.of(sheetContext).pop(draft),
            ),
            child: Column(
              children: [
                for (var index = 0; index < pilihan.length; index++) ...[
                  if (index > 0) const SizedBox(height: V2Space.lg),
                  V2RawatOptionRow(
                    label: pilihan[index],
                    selected: pilihan[index] == draft,
                    onTap: () =>
                        setSheetState(() => draft = pilihan[index]),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _kembali() {
    if (_berubah) {
      setState(() => _dialog = true);
      return;
    }
    Navigator.of(context).pop();
  }

  void _konfirmasi() {
    if (_stokKurang) return;
    final item = designRawatBaru.copyWith(
      obat: _obat.nama,
      jumlahObat: _jumlah,
    );
    widget.onSaved?.call(item);
    Navigator.of(context).pushReplacement(V2RawatSavedPage.route());
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_berubah && !_dialog,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_dialog) {
          setState(() => _dialog = false);
          return;
        }
        _kembali();
      },
      child: Theme(
        data: V2Theme.light,
        child: Scaffold(
          backgroundColor: V2Colors.canvas,
          body: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    V2AppBar(
                      title: 'Konfirmasi perawatan',
                      onBack: _kembali,
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
                            V2SelectField(
                              label: 'Tanggal',
                              value: labelTanggalRawatLengkap(_tanggal),
                              icon: V2IconName.calendar,
                              onTap: _pilihTanggal,
                            ),
                            const SizedBox(height: V2Space.lg),
                            V2SelectField(
                              label: 'Tanaman',
                              value: _tanaman,
                              onTap: _pilihTanaman,
                            ),
                            const SizedBox(height: V2Space.lg),
                            V2SelectField(
                              label: 'Obat',
                              value: _obat.nama,
                              onTap: _pilihObat,
                            ),
                            const SizedBox(height: V2Space.lg),
                            _fieldJumlah(),
                            if (!_stokKurang) ...[
                              const SizedBox(height: V2Space.lg),
                              _kartuStok(),
                            ],
                          ],
                        ),
                      ),
                    ),
                    V2ActionBar(
                      actions: [
                        V2Button(
                          label: 'Konfirmasi',
                          onPressed: _konfirmasi,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_dialog) _lapisanDialog(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldJumlah() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Jumlah obat',
          style: V2Type.label.copyWith(color: V2Colors.ink),
        ),
        const SizedBox(height: V2Space.sm),
        V2QtyField(
          value: _jumlah,
          unit: 'botol',
          error: _stokKurang,
          onChanged: _setJumlah,
          onMinus: () => _setJumlah(_jumlah - 1),
          onPlus: () => _setJumlah(_jumlah + 1),
        ),
        if (_stokKurang) ...[
          const SizedBox(height: V2Space.sm),
          Row(
            children: [
              const V2Icon(
                V2IconName.error,
                size: 16,
                color: V2Colors.red700,
              ),
              const SizedBox(width: V2Space.sm),
              Text(
                'Stok hanya ${_obat.stok} botol',
                style: V2Type.label.copyWith(color: V2Colors.red700),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Kartu 120 “Stok berkurang” (frame 9.21/9.28). Tinggi minimum supaya
  /// kalimat sisa obat tidak terpotong pada skala teks besar (BUG-24).
  Widget _kartuStok() {
    return Container(
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.fromLTRB(
        V2Space.xl,
        V2Space.xl,
        V2Space.xl,
        V2Space.xl,
      ),
      decoration: BoxDecoration(
        color: V2Colors.white,
        borderRadius: BorderRadius.circular(V2Radius.card),
        boxShadow: V2Shadow.card,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Stok berkurang', style: V2Type.h2),
          const SizedBox(height: V2Space.sm),
          Text(
            _obat.labelSisa(_jumlah),
            style: V2Type.body.copyWith(color: V2Colors.muted),
          ),
        ],
      ),
    );
  }

  /// Scrim 60% dan dialog 342×260 di tengah layar penuh (frame 9.28).
  Widget _lapisanDialog() {
    return Positioned.fill(
      child: ColoredBox(
        color: V2Colors.ink.withValues(alpha: 0.6),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
            child: V2Dialog(
              title: 'Buang perubahan?',
              body: 'Isian yang diubah akan hilang.',
              type: V2DialogType.destructive,
              primaryLabel: 'Buang',
              onPrimary: () => Navigator.of(context).pop(),
              secondaryLabel: 'Lanjut isi',
              onSecondary: () => setState(() => _dialog = false),
            ),
          ),
        ),
      ),
    );
  }
}