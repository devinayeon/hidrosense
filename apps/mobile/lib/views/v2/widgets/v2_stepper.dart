import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/v2_tokens.dart';
import 'v2_icon.dart';

/// Stepper bulat dari component set `Stepper` (48px).
class V2Stepper extends StatelessWidget {
  const V2Stepper({
    super.key,
    required this.value,
    this.onMinus,
    this.onPlus,
    this.enabled = true,
  });

  final int value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundAction(icon: V2IconName.minus, onTap: enabled ? onMinus : null),
        const SizedBox(width: V2Space.lg),
        SizedBox(
          width: 56,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: V2Type.h2.copyWith(
              color: enabled ? V2Colors.ink : V2Colors.muted,
            ),
          ),
        ),
        const SizedBox(width: V2Space.lg),
        _RoundAction(icon: V2IconName.plus, onTap: enabled ? onPlus : null),
      ],
    );
  }
}

/// Field jumlah dengan tombol minus/plus 56px dari component set `Qty`.
///
/// Angka selalu abu ([V2Colors.muted]) kecuali saat [error], mengikuti state
/// `Qty`: Default/Focus abu, Error ink. [error] juga menyalakan border merah 3px
/// (frame 4.22 "Stok kurang"). Baris pesan galat tidak digambar di sini karena
/// di desain `Helper` berdiri sebagai saudara `Qty`, bukan di dalamnya.
///
/// Minus/plus bisa ditahan untuk mengubah nilai lebih cepat, dan bila
/// [onChanged] diisi angka di tengah bisa diketuk untuk diketik langsung —
/// keduanya supaya jumlah besar tidak perlu diketuk satu-satu (BUG-29).
class V2QtyField extends StatelessWidget {
  const V2QtyField({
    super.key,
    required this.value,
    this.unit = '',
    this.onMinus,
    this.onPlus,
    this.onChanged,
    this.enabled = true,
    this.error = false,
  });

  final int value;
  final String unit;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  /// Ubah nilai lewat angka yang diketuk; null berarti hanya lewat minus/plus.
  final ValueChanged<int>? onChanged;

  final bool enabled;
  final bool error;

  /// Dialog ketik cepat: memasukkan jumlah besar tanpa menekan plus berulang.
  Future<void> _ketik(BuildContext context) async {
    final ubah = onChanged;
    if (ubah == null) return;
    final hasil = await showDialog<int>(
      context: context,
      builder: (context) => _JumlahDialog(awal: value, unit: unit),
    );
    if (hasil != null && hasil > 0 && hasil != value) ubah(hasil);
  }

  @override
  Widget build(BuildContext context) {
    // Pil angka bisa diketuk hanya bila pemanggil menerima perubahan nilai.
    Widget isi = Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: V2Space.sm,
      runSpacing: V2Space.xs,
      children: [
        Text(
          '$value',
          style: V2Type.bodyStrong.copyWith(
            // Angka abu saat biasa, jadi ink saat galat (component `Qty`).
            color: error ? V2Colors.ink : V2Colors.muted,
          ),
        ),
        if (unit.isNotEmpty)
          Text(unit, style: V2Type.body.copyWith(color: V2Colors.muted)),
        if (enabled && onChanged != null)
          const V2Icon(
            V2IconName.edit,
            size: V2Icons.small,
            color: V2Colors.muted,
          ),
      ],
    );
    if (enabled && onChanged != null) {
      isi = Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(V2Radius.pill),
        child: InkWell(
          onTap: () => _ketik(context),
          borderRadius: BorderRadius.circular(V2Radius.pill),
          child: isi,
        ),
      );
    }

    return Row(
      children: [
        _RoundAction(
          icon: V2IconName.minus,
          size: 56,
          onTap: enabled ? onMinus : null,
        ),
        const SizedBox(width: V2Space.sm),
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(
              horizontal: V2Space.md,
              vertical: V2Space.sm,
            ),
            decoration: BoxDecoration(
              color: enabled ? V2Colors.white : V2Colors.gray200,
              borderRadius: BorderRadius.circular(V2Radius.pill),
              border: Border.all(
                color: error ? V2Colors.red700 : V2Colors.slate400,
                width: error ? 3 : 2,
              ),
            ),
            // `Wrap` supaya angka dan satuan turun baris, bukan meluber keluar
            // pil pada skala teks besar (BUG-24).
            child: isi,
          ),
        ),
        const SizedBox(width: V2Space.sm),
        _RoundAction(
          icon: V2IconName.plus,
          size: 56,
          onTap: enabled ? onPlus : null,
        ),
      ],
    );
  }
}

/// Tombol bulat minus/plus. Ditekan singkat = satu langkah; ditahan = berulang
/// supaya nilai besar (mis. 200) tidak perlu diketuk satu-satu (BUG-29).
/// Dialog "Jumlah": pemilik [TextEditingController] sendiri supaya tidak
/// dibuang sebelum animasi tutup selesai.
class _JumlahDialog extends StatefulWidget {
  const _JumlahDialog({required this.awal, required this.unit});

  final int awal;
  final String unit;

  @override
  State<_JumlahDialog> createState() => _JumlahDialogState();
}

class _JumlahDialogState extends State<_JumlahDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.awal}',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _simpan() => Navigator.of(context).pop(int.tryParse(_controller.text));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Jumlah'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: InputDecoration(
          suffixText: widget.unit.isEmpty ? null : widget.unit,
        ),
        onSubmitted: (_) => _simpan(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        TextButton(onPressed: _simpan, child: const Text('Simpan')),
      ],
    );
  }
}

class _RoundAction extends StatefulWidget {
  const _RoundAction({required this.icon, this.size = 48, this.onTap});

  final V2IconName icon;
  final double size;
  final VoidCallback? onTap;

  @override
  State<_RoundAction> createState() => _RoundActionState();
}

class _RoundActionState extends State<_RoundAction> {
  static const Duration _tahanAwal = Duration(milliseconds: 400);
  static const Duration _ulang = Duration(milliseconds: 90);

  Timer? _tunda;
  Timer? _berulang;

  @override
  void dispose() {
    _tunda?.cancel();
    _berulang?.cancel();
    super.dispose();
  }

  void _mulaiTahan(TapDownDetails _) {
    if (widget.onTap == null) return;
    _tunda = Timer(_tahanAwal, () {
      widget.onTap!.call();
      _berulang = Timer.periodic(_ulang, (_) => widget.onTap!.call());
    });
  }

  void _lepas([TapUpDetails? _]) {
    final sedangBerulang = _berulang != null;
    _tunda?.cancel();
    _tunda = null;
    _berulang?.cancel();
    _berulang = null;
    // Ketukan singkat: belum sempat berulang, jadi satu langkah di sini.
    if (!sedangBerulang) widget.onTap?.call();
  }

  void _batal() {
    _tunda?.cancel();
    _tunda = null;
    _berulang?.cancel();
    _berulang = null;
  }

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: widget.onTap == null ? V2Colors.gray200 : V2Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.onTap == null ? V2Colors.gray200 : V2Colors.slate400,
          width: 2,
        ),
      ),
      child: Center(
        child: V2Icon(
          widget.icon,
          size: 24,
          color: widget.onTap == null ? V2Colors.muted : V2Colors.ink,
        ),
      ),
    );

    if (widget.onTap == null) return content;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: Semantics(
        button: true,
        onTap: widget.onTap,
        child: InkWell(
          onTapDown: _mulaiTahan,
          onTapUp: _lepas,
          onTapCancel: _batal,
          customBorder: const CircleBorder(),
          child: content,
        ),
      ),
    );
  }
}
