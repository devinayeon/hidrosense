import 'package:flutter/material.dart';

import '../../../data/services/notification_permission_service.dart';
import '../components/v2_auth_assets.dart';
import '../components/v2_auth_state_view.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_button.dart';
import 'v2_home_page.dart';

/// Frame `1.10 Izin notifikasi`: minta izin pengingat semai setelah masuk.
///
/// Izinkan dan Nanti sama-sama lanjut ke beranda. Kalau [onAllow] tidak diisi,
/// tombol Aktifkan memanggil izin notifikasi sistem yang sungguhan.
class V2NotificationPermissionPage extends StatelessWidget {
  const V2NotificationPermissionPage({super.key, this.onAllow});

  final Future<void> Function()? onAllow;

  static Route<void> route({Future<void> Function()? onAllow}) {
    return MaterialPageRoute<void>(
      builder: (_) => V2NotificationPermissionPage(onAllow: onAllow),
    );
  }

  void _continue(BuildContext context) {
    Navigator.of(context).pushReplacement(V2HomePage.route());
  }

  Future<void> _activate(BuildContext context) async {
    await (onAllow ?? NotificationPermissionService.request)();
    if (context.mounted) _continue(context);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: V2Theme.light,
      child: Scaffold(
        backgroundColor: V2Colors.canvas,
        body: SafeArea(
          bottom: false,
          child: V2AuthStateView(
            illustration: V2AuthAssets.notificationPermission,
            title: 'Pengingat semai',
            body: 'Kami kabari saat semaian HSS 15.',
            topPadding: 52,
            actions: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                V2Button(
                  label: 'Aktifkan',
                  onPressed: () => _activate(context),
                ),
                const SizedBox(height: V2Space.sm),
                V2Button(
                  label: 'Nanti',
                  type: V2ButtonType.ghost,
                  onPressed: () => _continue(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
