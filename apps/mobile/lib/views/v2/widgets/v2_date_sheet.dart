import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import 'v2_bottom_sheet.dart';
import 'v2_button.dart';
import 'v2_icon.dart';

/// Sheet pemilih tanggal (`Sheet/Tanggal`).
class V2DateSheet extends StatelessWidget {
  const V2DateSheet({
    super.key,
    this.title = 'Pilih tanggal',
    required this.monthLabel,
    required this.days,
    this.selectedDay,
    this.onSelect,
    this.onPrevMonth,
    this.onNextMonth,
    this.confirmLabel = 'Pilih',
    this.onConfirm,
  });

  final String title;
  final String monthLabel;

  /// Angka hari; `null` berarti sel kosong sebelum hari pertama.
  final List<int?> days;
  final int? selectedDay;
  final ValueChanged<int>? onSelect;
  final VoidCallback? onPrevMonth;
  final VoidCallback? onNextMonth;
  final String confirmLabel;
  final VoidCallback? onConfirm;

  static const List<String> _weekdays = <String>[
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
    'Min',
  ];

  @override
  Widget build(BuildContext context) {
    return V2BottomSheet(
      title: title,
      actions: V2Button(label: confirmLabel, onPressed: onConfirm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onPrevMonth,
                icon: const V2Icon(V2IconName.back),
                tooltip: 'Bulan sebelumnya',
              ),
              Expanded(
                child: Text(
                  monthLabel,
                  textAlign: TextAlign.center,
                  style: V2Type.bodyStrong,
                ),
              ),
              IconButton(
                onPressed: onNextMonth,
                icon: const V2Icon(V2IconName.chevronRight),
                tooltip: 'Bulan berikutnya',
              ),
            ],
          ),
          const SizedBox(height: V2Space.sm),
          Row(
            children: [
              for (final weekday in _weekdays)
                Expanded(
                  child: Text(
                    weekday,
                    textAlign: TextAlign.center,
                    style: V2Type.caption.copyWith(color: V2Colors.muted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: V2Space.sm),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.05,
            children: [
              for (final day in days)
                day == null
                    ? const SizedBox.shrink()
                    : _DayCell(
                        day: day,
                        selected: day == selectedDay,
                        onTap: onSelect == null ? null : () => onSelect!(day),
                      ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.selected, this.onTap});

  final int day;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: selected ? V2Colors.blue500 : Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Center(
            child: Text(
              '$day',
              style: V2Type.body.copyWith(
                color: selected ? V2Colors.white : V2Colors.ink,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
