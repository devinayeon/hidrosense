import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';

/// Kartu Profil biru dari frame 3.1, 3.2, 3.11, dan 3.17.
///
/// Tinggi tetap 88, sudut 32, `Shadow/Card`. Avatar 56 berisi inisial; di
/// sebelahnya nama 16/24 SemiBold putih, lalu peran 14/20 Medium putih
/// (3.1/3.2) atau lencana status (3.11/3.17).
class V2AkunProfilCard extends StatelessWidget {
  const V2AkunProfilCard({
    super.key,
    required this.initials,
    required this.name,
    this.role,
    this.badge,
  });

  final String initials;
  final String name;

  /// Teks peran, mis. "Petani" atau "Pegawai".
  final String? role;

  /// Lencana status, mis. `V2Badge(label: 'Aman', status: success)`.
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    // 88 adalah tinggi minimum; nama, lencana, dan peran yang membesar
    // membuat kartu tumbuh.
    return Container(
      constraints: const BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.all(V2Space.lg),
      decoration: BoxDecoration(
        color: V2Colors.blue500,
        borderRadius: BorderRadius.circular(V2Radius.sheet),
        boxShadow: V2Shadow.card,
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: V2Colors.blue50,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: V2Type.h2.copyWith(color: V2Colors.blue700),
              ),
            ),
          ),
          const SizedBox(width: V2Space.lg),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: V2Type.bodyStrong.copyWith(color: V2Colors.white),
                ),
                if (badge != null) ...[
                  const SizedBox(height: V2Space.xs),
                  badge!,
                ],
                if (role != null)
                  Text(
                    role!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: V2Type.label.copyWith(color: V2Colors.white),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
