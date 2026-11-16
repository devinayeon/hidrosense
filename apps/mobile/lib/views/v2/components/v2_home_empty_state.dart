import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_checklist.dart';
import '../widgets/v2_icon.dart';
import '../widgets/v2_icon_button.dart';

/// Isi beranda Petani saat belum punya meja tanam.
///
/// Susunan dari frame `1.11 Beranda kosong (Petani)`: sapaan 28/36, badan
/// 16/24, lalu checklist tiga langkah.
class V2HomeEmptyState extends StatelessWidget {
  const V2HomeEmptyState({super.key, this.onOpenNotifications});

  final VoidCallback? onOpenNotifications;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        V2ScreenHeader(
          title: 'Halo, Budi',
          trailing: V2IconButton(
            icon: V2IconName.bell,
            onPressed: onOpenNotifications,
            semanticLabel: 'Notifikasi',
          ),
        ),
        const SizedBox(height: V2Space.lg),
        Text(
          'Mulai dengan 3 langkah.',
          style: V2Type.body.copyWith(color: V2Colors.muted),
        ),
        const SizedBox(height: V2Space.lg),
        const V2Checklist(
          title: 'Mulai kebun',
          items: [
            V2ChecklistItem(
              title: '1 Tambah meja',
              subtitle: 'Atur lubang',
              icon: V2IconName.sprout,
            ),
            V2ChecklistItem(
              title: '2 Tambah stok',
              subtitle: 'Benih, nutrisi, obat',
              icon: V2IconName.sprout,
            ),
            V2ChecklistItem(
              title: '3 Mulai semai',
              subtitle: 'Hitung 15 hari',
              icon: V2IconName.sprout,
            ),
          ],
        ),
      ],
    );
  }
}
