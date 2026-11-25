import 'package:flutter/material.dart';

import '../components/v2_group_label.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_icon.dart';
import '../widgets/v2_list_item.dart';

/// Satu notifikasi di halaman 2.4.
class V2Notification {
  const V2Notification({
    required this.title,
    required this.subtitle,
    this.icon = V2IconName.sprout,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final V2IconName icon;
  final VoidCallback? onTap;
}

/// Kelompok notifikasi: "Baru" dan "Sebelumnya".
class V2NotificationGroup {
  const V2NotificationGroup({required this.label, required this.items});

  final String label;
  final List<V2Notification> items;
}

/// Daftar notifikasi dari frame `2.4 Notifikasi`.
///
/// Dibuka dari bel di beranda 2.1. Isi desain dibagi dua kelompok, lalu tombol
/// "Tandai semua dibaca" di bawah.
class V2NotificationsPage extends StatelessWidget {
  const V2NotificationsPage({super.key, this.groups, this.onMarkAllRead});

  final List<V2NotificationGroup>? groups;
  final VoidCallback? onMarkAllRead;

  static const List<V2NotificationGroup> designGroups = [
    V2NotificationGroup(
      label: 'Baru',
      items: [
        V2Notification(
          title: 'Semaian HSS 15',
          subtitle: 'Siap pindah ke meja, 08.00',
        ),
        V2Notification(
          title: 'Stok menipis',
          subtitle: 'Butterhead sisa 2 pak, 07.30',
          icon: V2IconName.box,
        ),
      ],
    ),
    V2NotificationGroup(
      label: 'Sebelumnya',
      items: [
        V2Notification(
          title: 'Hujan sore',
          subtitle: 'Tunda semprot, 15.00',
          icon: V2IconName.cloud,
        ),
        V2Notification(title: 'Semaian HSS 15', subtitle: '12 Nov, 08.00'),
      ],
    ),
  ];

  static Route<void> route({
    List<V2NotificationGroup>? groups,
    VoidCallback? onMarkAllRead,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) =>
          V2NotificationsPage(groups: groups, onMarkAllRead: onMarkAllRead),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = groups ?? designGroups;
    return Theme(
      data: V2Theme.light,
      child: Scaffold(
        backgroundColor: V2Colors.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              V2AppBar(
                title: 'Notifikasi',
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    V2Space.xl,
                    V2Space.sm,
                    V2Space.xl,
                    V2Space.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final group in data) ...[
                        V2GroupLabel(group.label),
                        for (final item in group.items) ...[
                          const SizedBox(height: V2Space.sm),
                          V2ListItem(
                            title: item.title,
                            subtitle: item.subtitle,
                            icon: item.icon,
                            onTap: item.onTap,
                          ),
                        ],
                        const SizedBox(height: V2Space.sm),
                      ],
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    V2Space.xl,
                    0,
                    V2Space.xl,
                    V2Space.sm,
                  ),
                  child: V2Button(
                    label: 'Tandai semua dibaca',
                    type: V2ButtonType.ghost,
                    onPressed: onMarkAllRead,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
