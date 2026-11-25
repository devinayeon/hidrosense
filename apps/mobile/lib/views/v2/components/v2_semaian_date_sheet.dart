import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import '../widgets/v2_bottom_sheet.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_icon.dart';

const List<String> _namaBulan = <String>[
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

const List<String> _namaHari = <String>[
  'Sen',
  'Sel',
  'Rab',
  'Kam',
  'Jum',
  'Sab',
  'Min',
];

/// Sheet `Sheet/Tanggal` (frame 5.8): kalender bulanan dengan tanggal terpilih
/// dan tombol "Pilih".
///
/// Pilihan ditahan sebagai draf; tanggal baru dipakai setelah "Pilih" ditekan,
/// sama seperti sheet pilihan lain. [selected] menjadi tanggal awal sekaligus
/// bulan yang ditampilkan.
Future<DateTime?> showV2SemaianDateSheet(
  BuildContext context, {
  required DateTime selected,
}) {
  var draft = DateTime(selected.year, selected.month, selected.day);
  var bulan = DateTime(draft.year, draft.month);

  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: Colors.transparent,
    // Frame 5.8 memakai scrim 60%, lebih gelap dari sheet pilihan lain.
    barrierColor: V2Colors.ink.withValues(alpha: 0.6),
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheet) => V2BottomSheet(
        title: 'Pilih tanggal',
        actions: V2Button(
          label: 'Pilih',
          onPressed: () => Navigator.of(sheetContext).pop(draft),
        ),
        child: _V2SemaianCalendar(
          bulan: bulan,
          terpilih: draft,
          onPrevious: () =>
              setSheet(() => bulan = DateTime(bulan.year, bulan.month - 1)),
          onNext: () =>
              setSheet(() => bulan = DateTime(bulan.year, bulan.month + 1)),
          onPick: (tanggal) => setSheet(() => draft = tanggal),
        ),
      ),
    ),
  );
}

class _V2SemaianCalendar extends StatelessWidget {
  const _V2SemaianCalendar({
    required this.bulan,
    required this.terpilih,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
  });

  final DateTime bulan;
  final DateTime terpilih;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    // Senin sebagai kolom pertama; 1 Nov 2026 jatuh di kolom Minggu.
    final offset = DateTime(bulan.year, bulan.month, 1).weekday - 1;
    final jumlahHari = DateTime(bulan.year, bulan.month + 1, 0).day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 48,
          child: Row(
            children: [
              _BulanButton(icon: V2IconName.back, onTap: onPrevious),
              Expanded(
                child: Text(
                  '${_namaBulan[bulan.month - 1]} ${bulan.year}',
                  textAlign: TextAlign.center,
                  style: V2Type.bodyStrong,
                ),
              ),
              _BulanButton(icon: V2IconName.chevronRight, onTap: onNext),
            ],
          ),
        ),
        const SizedBox(height: V2Space.lg),
        Row(
          children: [
            for (final hari in _namaHari)
              SizedBox(
                width: 48,
                height: 24,
                child: Center(
                  child: Text(
                    hari,
                    style: V2Type.label.copyWith(color: V2Colors.muted),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: V2Space.lg),
        for (var minggu = 0; minggu < 6; minggu++) ...[
          if (minggu > 0) const SizedBox(height: V2Space.lg),
          Row(
            children: [
              for (var kolom = 0; kolom < 7; kolom++)
                _HariCell(
                  tanggal: _tanggal(minggu, kolom, offset, jumlahHari),
                  terpilih: terpilih,
                  onPick: onPick,
                ),
            ],
          ),
        ],
      ],
    );
  }

  DateTime? _tanggal(int minggu, int kolom, int offset, int jumlahHari) {
    final hari = minggu * 7 + kolom - offset + 1;
    if (hari < 1 || hari > jumlahHari) return null;
    return DateTime(bulan.year, bulan.month, hari);
  }
}

class _HariCell extends StatelessWidget {
  const _HariCell({
    required this.tanggal,
    required this.terpilih,
    required this.onPick,
  });

  final DateTime? tanggal;
  final DateTime terpilih;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final hari = tanggal;
    if (hari == null) return const SizedBox(width: 48, height: 48);
    final dipilih =
        hari.year == terpilih.year &&
        hari.month == terpilih.month &&
        hari.day == terpilih.day;

    return SizedBox(
      width: 48,
      height: 48,
      child: Material(
        color: dipilih ? V2Colors.blue500 : Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onPick(hari),
          customBorder: const CircleBorder(),
          child: Center(
            child: Text(
              '${hari.day}',
              style: dipilih
                  ? V2Type.bodyStrong.copyWith(color: V2Colors.white)
                  : V2Type.body,
            ),
          ),
        ),
      ),
    );
  }
}

class _BulanButton extends StatelessWidget {
  const _BulanButton({required this.icon, required this.onTap});

  final V2IconName icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Center(child: V2Icon(icon)),
        ),
      ),
    );
  }
}
