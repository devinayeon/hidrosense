import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import '../widgets/v2_icon.dart';

/// Baris pilihan di page 09 (obat 9.19/9.20 dan tanaman 9.9).
///
/// Bentuknya sama dengan `OptionRow`, tetapi teks mulai 27 dan bulatan pilihan
/// berjarak 19 dari tepi kanan seperti frame page 09. `V2OptionRow` shared
/// dipakai apa adanya oleh halaman lain (inset 16/24).
class V2RawatOptionRow extends StatelessWidget {
  const V2RawatOptionRow({
    super.key,
    required this.label,
    this.selected = false,
    this.enabled = true,
    this.onTap,
  });

  final String label;
  final bool selected;

  /// Saat `false` baris berlatar abu dan tidak bisa dipilih (obat habis).
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(V2Radius.pill),
        child: Container(
          height: 56,
          padding: const EdgeInsets.only(left: 25, right: 17),
          decoration: BoxDecoration(
            color: !enabled
                ? V2Colors.gray200
                : selected
                ? V2Colors.blue50
                : V2Colors.white,
            borderRadius: BorderRadius.circular(V2Radius.pill),
            border: Border.all(
              color: selected ? V2Colors.blue700 : V2Colors.slate400,
              width: selected ? 3 : 2,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: V2Type.bodyStrong.copyWith(
                    color: enabled ? V2Colors.ink : V2Colors.muted,
                  ),
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