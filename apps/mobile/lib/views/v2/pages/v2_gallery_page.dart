import 'package:flutter/material.dart';

import '../components/v2_foundation_gallery.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_error_state.dart';
import '../widgets/v2_group_list.dart';
import '../widgets/v2_icon.dart';
import '../widgets/v2_list_item.dart';
import 'v2_beranda_page.dart';
import 'v2_cycle_detail_page.dart';
import 'v2_employee_list_page.dart';
import 'v2_inactive_account_page.dart';
import 'v2_notification_permission_page.dart';
import 'v2_notifications_page.dart';
import 'v2_offline_login_page.dart';
import 'v2_onboarding_page.dart';
import 'v2_penjualan_list_page.dart';
import 'v2_sinkron_page.dart';

/// Halaman review semua widget reusable v2.
///
/// Bagian atas adalah galeri widget dari `00 Foundations`; bagian bawah berisi
/// pintasan ke halaman alur supaya tiap slice bisa dibuka langsung tanpa
/// menelusuri menu. Belum ada alur bisnis di sini.
class V2GalleryPage extends StatelessWidget {
  const V2GalleryPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const V2GalleryPage());

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: V2Theme.light,
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: V2Colors.canvas,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: SafeArea(
              bottom: false,
              child: V2AppBar(
                title: 'Review widget v2',
                onBack: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                V2Space.lg,
                V2Space.lg,
                V2Space.lg,
                V2Space.xxxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const V2FlowNote(
                    title: 'HidroSense v2',
                    note:
                        'Semua widget di halaman ini disadur dari '
                        '"00 Foundations". Pakai token V2Colors, V2Type, dan '
                        'V2Space supaya tampilan tetap konsisten.',
                    roleLabel: 'Review internal',
                  ),
                  const SizedBox(height: V2Space.xl),
                  const V2FoundationGallery(),
                  const SizedBox(height: V2Space.xxl),
                  Text('Halaman alur v2', style: V2Type.h2),
                  const SizedBox(height: V2Space.md),
                  V2GroupList(
                    children: [
                      _FlowRow(
                        icon: V2IconName.sprout,
                        title: 'Onboarding & Auth (01)',
                        subtitle: 'Splash, welcome, login, izin notifikasi',
                        route: V2OnboardingPage.route,
                      ),
                      _FlowRow(
                        icon: V2IconName.home,
                        title: 'Beranda & Notifikasi (02)',
                        subtitle: 'Beranda Petani, notifikasi, detail siklus',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2BerandaPage(),
                        ),
                      ),
                      _FlowRow(
                        icon: V2IconName.user,
                        title: 'Akun (03)',
                        subtitle: 'Daftar akun pegawai',
                        route: V2EmployeeListPage.route,
                      ),
                      _FlowRow(
                        icon: V2IconName.chart,
                        title: 'Penjualan (08)',
                        subtitle: 'Daftar penjualan dan ringkasan',
                        route: V2PenjualanListPage.route,
                      ),
                      _FlowRow(
                        icon: V2IconName.sync,
                        title: 'Sinkron & Profil (11)',
                        subtitle: 'Keadaan sinkron, antrean, konflik',
                        route: V2SinkronPage.route,
                      ),
                    ],
                  ),
                  const SizedBox(height: V2Space.xl),
                  Text('Keadaan khusus', style: V2Type.h2),
                  const SizedBox(height: V2Space.md),
                  V2GroupList(
                    children: [
                      _FlowRow(
                        icon: V2IconName.bell,
                        title: 'Notifikasi (2.4)',
                        subtitle: 'Dua kelompok + tandai semua dibaca',
                        route: V2NotificationsPage.route,
                      ),
                      _FlowRow(
                        icon: V2IconName.layers,
                        title: 'Detail siklus (2.7)',
                        subtitle: 'Cincin 60 hari dan linimasa',
                        route: V2CycleDetailPage.route,
                      ),
                      _FlowRow(
                        icon: V2IconName.warning,
                        title: 'Akun nonaktif (1.8)',
                        subtitle: 'Pesan akun dinonaktifkan',
                        route: V2InactiveAccountPage.route,
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.cloud,
                        title: 'Offline saat masuk (1.9)',
                        subtitle: 'Login tanpa internet',
                        route: V2OfflineLoginPage.route,
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.bell,
                        title: 'Izin notifikasi (1.10)',
                        subtitle: 'Minta izin notifikasi sistem',
                        route: V2NotificationPermissionPage.route,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Satu baris pintasan menuju halaman alur: judul, subjudul, dan tanda panah.
class _FlowRow extends StatelessWidget {
  const _FlowRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    this.iconTone = V2ListItemIconTone.blue,
  });

  final V2IconName icon;
  final String title;
  final String subtitle;
  final Route<void> Function() route;
  final V2ListItemIconTone iconTone;

  @override
  Widget build(BuildContext context) {
    return V2ListItem(
      icon: icon,
      iconTone: iconTone,
      title: title,
      subtitle: subtitle,
      onTap: () => Navigator.of(context).push(route()),
    );
  }
}
