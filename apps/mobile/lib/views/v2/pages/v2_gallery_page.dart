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
import 'v2_inventaris_detail_page.dart';
import 'v2_inventaris_form_page.dart';
import 'v2_inventaris_list_page.dart';
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
                        icon: V2IconName.box,
                        title: 'Inventaris (04)',
                        subtitle: 'Daftar stok, saringan, dan pencarian',
                        route: V2InventarisListPage.route,
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
                      _FlowRow(
                        icon: V2IconName.user,
                        title: 'Stok pegawai (4.2)',
                        subtitle: 'Tab bar peran pegawai',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2InventarisListPage.pegawai(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.box,
                        title: 'Stok memuat (4.3)',
                        subtitle: 'Empat rangka kartu sebelum daftar',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2InventarisListPage.loading(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.warning,
                        title: 'Stok gagal memuat (4.4)',
                        subtitle: 'Pesan gagal dan tombol coba lagi',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2InventarisListPage.error(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.box,
                        title: 'Stok kosong (4.5)',
                        subtitle: 'Belum ada barang tercatat',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2InventarisListPage.empty(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.search,
                        title: 'Stok tanpa hasil (4.6)',
                        subtitle: 'Pencarian "Zzz" tidak ketemu',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) =>
                              const V2InventarisListPage.noResults(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.box,
                        title: 'Pilih jenis (4.7)',
                        subtitle: 'Sheet jenis barang terbuka',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) =>
                              const V2InventarisListPage.filterSheet(),
                        ),
                      ),
                      _FlowRow(
                        icon: V2IconName.sprout,
                        title: 'Stok jenis Benih (4.8)',
                        subtitle: 'Saringan jenis aktif',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) =>
                              const V2InventarisListPage.jenisBenih(),
                        ),
                      ),
                      _FlowRow(
                        icon: V2IconName.warning,
                        title: 'Stok menipis Benih (4.9)',
                        subtitle: 'Saringan jenis dan menipis',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) =>
                              const V2InventarisListPage.menipisBenih(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.box,
                        title: 'Tambah barang (4.10)',
                        subtitle: 'Form isian barang baru',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2InventarisFormPage.create(),
                        ),
                      ),
                      _FlowRow(
                        icon: V2IconName.care,
                        title: 'Tambah barang, obat (4.11)',
                        subtitle: 'Jenis Obat dengan pilihan obat',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2InventarisFormPage.obat(),
                        ),
                      ),
                      _FlowRow(
                        icon: V2IconName.care,
                        title: 'Pilih obat (4.12)',
                        subtitle: 'Sheet pilihan obat terbuka',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) =>
                              const V2InventarisFormPage.pilihObat(),
                        ),
                      ),
                      _FlowRow(
                        icon: V2IconName.box,
                        title: 'Tambah barang, keyboard (4.13)',
                        subtitle: 'Kolom stok awal terfokus',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2InventarisFormPage.keyboard(),
                        ),
                      ),
                      _FlowRow(
                        icon: V2IconName.warning,
                        title: 'Tambah barang, validasi (4.14)',
                        subtitle: 'Tiga kolom bergalat',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) =>
                              const V2InventarisFormPage.validation(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.check,
                        title: 'Barang ditambahkan (4.15)',
                        subtitle: 'Baris baru dan toast sukses',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2InventarisListPage.added(),
                        ),
                      ),
                      _FlowRow(
                        icon: V2IconName.cloud,
                        title: 'Tersimpan di HP (4.16)',
                        subtitle: 'Banner offline dan badge antrean',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2InventarisListPage.offline(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.box,
                        title: 'Detail barang baru (4.17)',
                        subtitle: 'Barang baru dengan satu riwayat',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2InventarisDetailPage.baru(),
                        ),
                      ),
                      _FlowRow(
                        icon: V2IconName.warning,
                        title: 'Detail barang menipis (4.18)',
                        subtitle: 'Badge Menipis dan riwayat penuh',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) =>
                              const V2InventarisDetailPage.menipis(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.box,
                        title: 'Detail barang (4.19)',
                        subtitle: 'Stok cukup dengan riwayat',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2InventarisDetailPage.biasa(),
                        ),
                      ),
                      _FlowRow(
                        icon: V2IconName.close,
                        title: 'Detail barang habis (4.20)',
                        subtitle: 'Stok habis dan catat stok masuk',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2InventarisDetailPage.habis(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.plus,
                        title: 'Catat stok (4.21)',
                        subtitle: 'Sheet catat stok terbuka',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) =>
                              const V2InventarisDetailPage.catatSheet(),
                        ),
                      ),
                      _FlowRow(
                        icon: V2IconName.error,
                        title: 'Stok kurang (4.22)',
                        subtitle: 'Jumlah melebihi stok',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) =>
                              const V2InventarisDetailPage.catatError(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.check,
                        title: 'Stok tercatat (4.23)',
                        subtitle: 'Riwayat baru dan toast sukses',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2InventarisDetailPage.tercatat(),
                        ),
                      ),
                      _FlowRow(
                        icon: V2IconName.trash,
                        title: 'Detail barang arsip (4.29)',
                        subtitle: 'Barang arsip tanpa aksi',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2InventarisDetailPage.arsip(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
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
