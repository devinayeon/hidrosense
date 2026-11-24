import 'package:flutter/material.dart';

import '../components/v2_panen_data.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_bottom_sheet.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_chip.dart';
import '../widgets/v2_icon.dart';
import '../widgets/v2_text_field.dart';

/// Buang baris ganda (id pemindahan sama) lalu saring daftar tanaman pemilih
/// "Catat panen" (BUG-33): hanya yang cocok pencarian teks dan (opsional)
/// meja terpilih yang lolos.
///
/// Data dari server bisa memuat id pemindahan yang sama lebih dari sekali;
/// di sini tiap id ditampilkan sekali saja. Pencarian tidak peka huruf besar
/// kecil dan mencocokkan nama meja maupun varietas.
List<V2PanenEstimasi> saringPilihanTanamanPanen(
  List<V2PanenEstimasi> pilihan, {
  String cari = '',
  String? meja,
}) {
  final hasil = <V2PanenEstimasi>[];
  final terlihat = <String>{};
  final kueri = cari.trim().toLowerCase();
  for (final item in pilihan) {
    if (meja != null && item.meja != meja) continue;
    if (kueri.isNotEmpty &&
        !'${item.meja} ${item.varietas}'.toLowerCase().contains(kueri)) {
      continue;
    }
    if (!terlihat.add(item.kunci)) continue;
    hasil.add(item);
  }
  return hasil;
}

/// Buka sheet "Pilih tanaman" (frame 7.9) dengan pencarian, filter meja, dan
/// daftar yang bisa digulir (BUG-33).
Future<V2PanenEstimasi?> showV2PanenTanamanSheet(
  BuildContext context, {
  required List<V2PanenEstimasi> pilihan,
  V2PanenEstimasi? terpilih,
}) {
  return showV2BottomSheet<V2PanenEstimasi>(
    context,
    child: V2PanenTanamanSheet(pilihan: pilihan, terpilih: terpilih),
  );
}

/// Isi sheet "Pilih tanaman": isian cari, chip filter meja, daftar baris
/// bertanaman aktif, dan tombol "Pilih".
///
/// Daftar digulir di dalam tinggi terbatas supaya ratusan batch tidak
/// meluber keluar layar; tiap baris menampilkan meja, varietas, asal semaian,
/// tanggal pindah, HSS, dan sisa tanaman aktif agar batch terlihat berbeda.
class V2PanenTanamanSheet extends StatefulWidget {
  const V2PanenTanamanSheet({
    super.key,
    required this.pilihan,
    this.terpilih,
  });

  final List<V2PanenEstimasi> pilihan;
  final V2PanenEstimasi? terpilih;

  @override
  State<V2PanenTanamanSheet> createState() => _V2PanenTanamanSheetState();
}

class _V2PanenTanamanSheetState extends State<V2PanenTanamanSheet> {
  final TextEditingController _cari = TextEditingController();
  String _kueri = '';
  String? _meja;
  V2PanenEstimasi? _draft;

  @override
  void initState() {
    super.initState();
    _draft =
        widget.terpilih ??
        (widget.pilihan.isEmpty ? null : widget.pilihan.first);
    _cari.addListener(_onCariChanged);
  }

  void _onCariChanged() => setState(() => _kueri = _cari.text);

  @override
  void dispose() {
    _cari
      ..removeListener(_onCariChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mejaTersedia = <String>[];
    for (final item in widget.pilihan) {
      if (!mejaTersedia.contains(item.meja)) mejaTersedia.add(item.meja);
    }
    final hasil = saringPilihanTanamanPanen(
      widget.pilihan,
      cari: _kueri,
      meja: _meja,
    );
    final tinggiSheet = MediaQuery.sizeOf(context).height * 0.9;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: tinggiSheet),
      child: V2BottomSheet(
        title: 'Pilih tanaman',
        flexible: true,
        actions: V2Button(
          label: 'Pilih',
          onPressed: _draft == null
              ? null
              : () => Navigator.of(context).pop(_draft),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            V2TextField(
              label: 'Cari tanaman',
              hint: 'Nama meja atau varietas',
              controller: _cari,
            ),
            if (mejaTersedia.length > 1) ...[
              const SizedBox(height: V2Space.md),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    V2Chip(
                      label: 'Semua meja',
                      selected: _meja == null,
                      onTap: () => setState(() => _meja = null),
                    ),
                    for (final meja in mejaTersedia) ...[
                      const SizedBox(width: V2Space.sm),
                      V2Chip(
                        label: meja,
                        selected: _meja == meja,
                        onTap: () => setState(() => _meja = meja),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: V2Space.md),
            if (hasil.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: V2Space.lg),
                child: Text(
                  'Tidak ada tanaman yang cocok. Ubah pencarian atau filter meja.',
                  style: V2Type.body.copyWith(color: V2Colors.muted),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: hasil.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: V2Space.md),
                  itemBuilder: (context, index) {
                    final item = hasil[index];
                    return _BarisTanaman(
                      item: item,
                      selected: item.kunci == _draft?.kunci,
                      onTap: () => setState(() => _draft = item),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Baris pilihan tanaman di sheet 7.9 yang aman pada skala teks 2.0.
///
/// Bentuknya sama dengan `OptionRow`, tetapi teks mulai 25 dan bulatan pilihan
/// berjarak 17 dari tepi kanan. Tingginya minimum 56 dp dan boleh bertambah
/// supaya dua baris teks tidak terpotong.
class _BarisTanaman extends StatelessWidget {
  const _BarisTanaman({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final V2PanenEstimasi item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(V2Radius.pill),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.only(
            left: 25,
            right: 17,
            top: V2Space.sm,
            bottom: V2Space.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? V2Colors.blue50 : V2Colors.white,
            borderRadius: BorderRadius.circular(V2Radius.pill),
            border: Border.all(
              color: selected ? V2Colors.blue700 : V2Colors.slate400,
              width: selected ? 3 : 2,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.meja}, ${item.varietas}',
                      softWrap: true,
                      style: V2Type.bodyStrong,
                    ),
                    const SizedBox(height: V2Space.xs),
                    Text(
                      item.labelRincian,
                      softWrap: true,
                      style: V2Type.label.copyWith(color: V2Colors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: V2Space.md),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: selected ? V2Colors.blue500 : V2Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? V2Colors.blue500 : V2Colors.slate400,
                    width: 2,
                  ),
                ),
                child: selected
                    ? const V2Icon(
                        V2IconName.check,
                        size: 16,
                        color: V2Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
