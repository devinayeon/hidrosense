import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import 'v2_bottom_sheet.dart';
import 'v2_button.dart';
import 'v2_option_row.dart';

/// Sheet pilihan (`Sheet/Pilih`) dengan daftar OptionRow.
class V2PickSheet extends StatelessWidget {
  const V2PickSheet({
    super.key,
    required this.title,
    required this.options,
    required this.selectedIndex,
    this.onSelect,
    this.confirmLabel = 'Pilih',
    this.onConfirm,
  });

  final String title;
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int>? onSelect;
  final String confirmLabel;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    return V2BottomSheet(
      title: title,
      actions: V2Button(label: confirmLabel, onPressed: onConfirm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < options.length; index++) ...[
            if (index > 0) const SizedBox(height: V2Space.md),
            V2OptionRow(
              label: options[index],
              state: index == selectedIndex
                  ? V2OptionState.selected
                  : V2OptionState.normal,
              onTap: onSelect == null ? null : () => onSelect!(index),
            ),
          ],
        ],
      ),
    );
  }
}

/// Sheet catat stok masuk/keluar (`Sheet/CatatStok`).
class V2StockSheet extends StatelessWidget {
  const V2StockSheet({
    super.key,
    this.title = 'Catat stok',
    required this.modeIndex,
    this.onModeChanged,
    required this.value,
    this.unit = 'pak',
    this.onMinus,
    this.onPlus,
    this.preview,
    this.error,
    this.confirmLabel = 'Simpan',
    this.onConfirm,
  });

  final String title;
  final int modeIndex;
  final ValueChanged<int>? onModeChanged;
  final int value;
  final String unit;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final String? preview;
  final String? error;
  final String confirmLabel;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    return V2BottomSheet(
      title: title,
      actions: V2Button(label: confirmLabel, onPressed: onConfirm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 56,
            padding: const EdgeInsets.all(V2Space.xs),
            decoration: BoxDecoration(
              color: V2Colors.gray200,
              borderRadius: BorderRadius.circular(V2Radius.pill),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ModeTab(
                    label: 'Masuk',
                    selected: modeIndex == 0,
                    onTap: onModeChanged == null
                        ? null
                        : () => onModeChanged!(0),
                  ),
                ),
                Expanded(
                  child: _ModeTab(
                    label: 'Keluar',
                    selected: modeIndex == 1,
                    onTap: onModeChanged == null
                        ? null
                        : () => onModeChanged!(1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: V2Space.lg),
          _QtyRow(value: value, unit: unit, onMinus: onMinus, onPlus: onPlus),
          const SizedBox(height: V2Space.lg),
          if (error != null)
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: V2Colors.red700,
                ),
                const SizedBox(width: V2Space.sm),
                Expanded(
                  child: Text(
                    error!,
                    style: V2Type.label.copyWith(color: V2Colors.red700),
                  ),
                ),
              ],
            )
          else
            Text(
              preview ?? '',
              style: V2Type.body.copyWith(color: V2Colors.muted),
            ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? V2Colors.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(V2Radius.pill),
        ),
        child: Text(
          label,
          style: V2Type.bodyStrong.copyWith(
            color: selected ? V2Colors.white : V2Colors.slate600,
          ),
        ),
      ),
    );
  }
}

class _QtyRow extends StatelessWidget {
  const _QtyRow({
    required this.value,
    required this.unit,
    this.onMinus,
    this.onPlus,
  });

  final int value;
  final String unit;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundAction(icon: Icons.remove, onTap: onMinus),
        const SizedBox(width: V2Space.sm),
        Expanded(
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: V2Colors.white,
              borderRadius: BorderRadius.circular(V2Radius.pill),
              border: Border.all(color: V2Colors.slate400, width: 2),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$value', style: V2Type.bodyStrong),
                  const SizedBox(width: V2Space.sm),
                  Text(
                    unit,
                    style: V2Type.body.copyWith(color: V2Colors.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: V2Space.sm),
        _RoundAction(icon: Icons.add, onTap: onPlus),
      ],
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: V2Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: V2Colors.slate400, width: 2),
          ),
          child: Icon(icon, size: 24, color: V2Colors.ink),
        ),
      ),
    );
  }
}
