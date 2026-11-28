import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import '../widgets/v2_bottom_sheet.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_icon.dart';
import '../widgets/v2_segmented.dart';
import '../widgets/v2_stepper.dart';
import 'v2_inventaris_data.dart';

/// Hasil sheet "Catat stok": arah catatan dan jumlahnya.
class V2CatatStok {
  const V2CatatStok({required this.masuk, required this.jumlah});

  /// `true` berarti stok masuk, `false` berarti dipakai.
  final bool masuk;

  /// Jumlah satuan yang dicatat.
  final int jumlah;
}

/// Tampilkan sheet "Catat stok" (frame 4.21) di atas halaman detail.
Future<V2CatatStok?> showV2CatatStokSheet(
  BuildContext context, {
  required V2InventarisItem item,
  bool masuk = false,
  int jumlah = 1,
}) {
  return showV2BottomSheet<V2CatatStok>(
    context,
    child: V2CatatStokSheet(
      item: item,
      initialMasuk: masuk,
      initialJumlah: jumlah,
    ),
  );
}

/// Isi sheet "Catat stok" (frame 4.21 dan 4.22).
///
/// Susunannya sama dengan component `Sheet/CatatStok`: segmented `Pakai`/`Masuk`,
/// field `Qty`, satu baris keterangan (pratinjau stok atau pesan galat), lalu
/// tombol `Simpan`. Jumlah yang melebihi batas ditolak di sheet ini supaya
/// pesannya tidak baru muncul di halaman detail:
///
/// - `Pakai`: tidak boleh melebihi stok yang ada, pesan "Stok hanya N satuan"
///   (frame 4.22).
/// - `Masuk`: tidak boleh melebihi 10000 satuan dalam sekali input, dan tidak
///   boleh membuat saldo melewati batas backend (`stok_saldo` maksimal
///   9999999999.99), pesan "Maksimal N satuan".
class V2CatatStokSheet extends StatefulWidget {
  const V2CatatStokSheet({
    super.key,
    required this.item,
    this.initialMasuk = false,
    this.initialJumlah = 1,
  });

  final V2InventarisItem item;

  /// `true` membuka sheet pada mode `Masuk`; bawaan `Pakai` (frame 4.21).
  final bool initialMasuk;

  final int initialJumlah;

  @override
  State<V2CatatStokSheet> createState() => _V2CatatStokSheetState();
}

class _V2CatatStokSheetState extends State<V2CatatStokSheet> {
  /// 0 = `Pakai`, 1 = `Masuk`.
  late int _mode = widget.initialMasuk ? 1 : 0;
  late int _jumlah = widget.initialJumlah;

  bool get _masuk => _mode == 1;

  /// Stok yang sedang dicatat (jumlahnya selalu bulat di data contoh ini).
  int get _stok => widget.item.jumlah.round();

  /// Batas saldo backend: `stok_saldo.saldo_minor <= 999999999999`, yaitu
  /// 9999999999.99. Sheet memakai bilangan bulat, jadi batas masuk adalah sisa
  /// sampai batas tersebut.
  static const int _batasSaldo = 9999999999;

  /// Batas satu kali catat stok masuk (permintaan klien 28 Nov 2026): jumlah
  /// masuk per input paling banyak 10000, terpisah dari batas saldo.
  static const int _batasMasuk = 10000;

  /// Jumlah masuk paling besar: 10000 sekali input, atau sisa sampai batas
  /// saldo backend bila lebih kecil.
  int get _maksMasuk {
    final sisaSaldo = _batasSaldo - _stok;
    if (sisaSaldo <= 0) return 0;
    return sisaSaldo < _batasMasuk ? sisaSaldo : _batasMasuk;
  }

  /// Stok sesudah catatan dipakai.
  int get _stokJadi => _masuk ? _stok + _jumlah : _stok - _jumlah;

  /// `Pakai` melebihi stok yang ada.
  bool get _galatStok => !_masuk && _jumlah > _stok;

  /// `Masuk` membuat saldo melewati batas backend.
  bool get _galatMaks => _masuk && _jumlah > _maksMasuk;

  bool get _galat => _galatStok || _galatMaks;

  /// Keterangan saat tidak ada galat, mis. `Pakai 2 pak. Stok jadi 10 pak.`
  String get _preview =>
      '${_masuk ? 'Masuk' : 'Pakai'} $_jumlah ${widget.item.satuan}. '
      'Stok jadi $_stokJadi ${widget.item.satuan}.';

  void _ubahJumlah(int delta) {
    final berikutnya = _jumlah + delta;
    if (berikutnya < 1) return;
    // Tombol plus berhenti di batas masuk supaya tidak melewati saldo backend.
    if (_masuk && berikutnya > _maksMasuk) return;
    setState(() => _jumlah = berikutnya);
  }

  /// Ketik langsung jumlah besar lewat dialog angka (BUG-37).
  void _setJumlah(int value) {
    if (value < 1) return;
    setState(() => _jumlah = value);
  }

  void _simpan() {
    if (_galat) return;
    Navigator.of(context).pop(V2CatatStok(masuk: _masuk, jumlah: _jumlah));
  }

  @override
  Widget build(BuildContext context) {
    return V2BottomSheet(
      title: 'Catat stok',
      actions: V2Button(label: 'Simpan', onPressed: _simpan),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          V2Segmented(
            labels: const <String>['Pakai', 'Masuk'],
            selectedIndex: _mode,
            onChanged: (index) => setState(() => _mode = index),
          ),
          const SizedBox(height: V2Space.lg),
          V2QtyField(
            value: _jumlah,
            unit: widget.item.satuan,
            error: _galat,
            onChanged: _setJumlah,
            onMinus: () => _ubahJumlah(-1),
            onPlus: _masuk && _jumlah >= _maksMasuk
                ? null
                : () => _ubahJumlah(1),
          ),
          const SizedBox(height: V2Space.lg),
          if (_galat) _pesanGalat() else _keterangan(),
        ],
      ),
    );
  }

  /// Satu baris pratinjau 16/24 muted (frame 4.21).
  Widget _keterangan() {
    return Text(_preview, style: V2Type.body.copyWith(color: V2Colors.muted));
  }

  /// Baris galat 14/20 red700 dengan ikon 16 (frame 4.22).
  Widget _pesanGalat() {
    final warna = V2Colors.red700;
    final pesan = _galatStok
        ? 'Stok hanya $_stok ${widget.item.satuan}'
        : 'Maksimal $_maksMasuk ${widget.item.satuan}';
    return Row(
      children: [
        V2Icon(V2IconName.error, size: V2Icons.small, color: warna),
        const SizedBox(width: V2Space.sm),
        Expanded(
          child: Text(pesan, style: V2Type.label.copyWith(color: warna)),
        ),
      ],
    );
  }
}
