import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import '../widgets/v2_icon.dart';

/// Baris akun pegawai pada frame 3.5, 3.6, 3.10, 3.16.
///
/// Sama bentuk dengan baris grup daftar: lead 48 bulat biru muda, nama 16/24
/// SemiBold, status 14/20 Medium, chevron 24. Bedanya di sini status
/// `Nonaktif` membuat nama dan status memakai `#4B5563` (state `Archived`).
class V2AkunEmployeeRow extends StatelessWidget {
  const V2AkunEmployeeRow({
    super.key,
    required this.name,
    required this.statusLine,
    this.active = true,
    this.onTap,
  });

  final String name;
  final String statusLine;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final titleColor = active ? V2Colors.ink : V2Colors.slate600;
    final content = Container(
      constraints: const BoxConstraints(minHeight: 80),
      padding: const EdgeInsets.symmetric(horizontal: V2Space.lg),
      color: V2Colors.white,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: V2Colors.blue50,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: V2Icon(V2IconName.user, color: V2Colors.blue700),
            ),
          ),
          const SizedBox(width: V2Space.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: V2Type.bodyStrong.copyWith(color: titleColor),
                ),
                const SizedBox(height: V2Space.xs),
                Text(
                  statusLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: V2Type.label.copyWith(
                    color: active ? V2Colors.muted : V2Colors.slate600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: V2Space.md),
          const V2Icon(V2IconName.chevronRight, color: V2Colors.muted),
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}
