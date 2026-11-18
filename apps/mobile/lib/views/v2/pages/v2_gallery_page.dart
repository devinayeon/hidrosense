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
import 'v2_pindah_meja_page.dart';
import 'v2_semaian_detail_page.dart';
import 'v2_semaian_edit_page.dart';
import 'v2_semaian_form_page.dart';
import 'v2_semaian_list_page.dart';
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
                        icon: V2IconName.sprout,
                        title: 'Semaian (05)',
                        subtitle: 'Daftar semaian, tambah, dan pindah ke meja',
                        route: V2SemaianListPage.route,
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
                        icon: V2IconName.edit,
                        title: 'Ubah barang (4.24)',
                        subtitle: 'Form ubah tanpa stok awal',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2InventarisFormPage.ubah(),
                        ),
                      ),
                      _FlowRow(
                        icon: V2IconName.check,
                        title: 'Perubahan tersimpan (4.25)',
                        subtitle: 'Detail dengan toast sukses',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2InventarisDetailPage.perubahan(),
                        ),
                      ),
                      _FlowRow(
                        icon: V2IconName.trash,
                        title: 'Arsipkan, konfirmasi (4.26)',
                        subtitle: 'Dialog arsip barang',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) =>
                              const V2InventarisDetailPage.arsipkanKonfirmasi(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.trash,
                        title: 'Barang diarsipkan (4.27)',
                        subtitle: 'Baris hilang dengan toast',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2InventarisListPage.archived(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.box,
                        title: 'Arsip (4.28)',
                        subtitle: 'Barang tersimpan tanpa lencana',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2InventarisListPage.arsip(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
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
                      _FlowRow(
                        icon: V2IconName.warning,
                        title: 'Buang perubahan (4.30)',
                        subtitle: 'Dialog konfirmasi buang isian',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) =>
                              const V2InventarisFormPage.buangPerubahan(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.sync,
                        title: 'Data sudah berubah (4.31)',
                        subtitle: 'Dialog muat ulang data terbaru',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2InventarisFormPage.dataBerubah(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.user,
                        title: 'Semaian pegawai (5.2)',
                        subtitle: 'Tab bar peran pegawai',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2SemaianListPage.pegawai(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.sprout,
                        title: 'Semaian memuat (5.3)',
                        subtitle: 'Empat rangka kartu sebelum daftar',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2SemaianListPage.loading(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.warning,
                        title: 'Semaian gagal memuat (5.4)',
                        subtitle: 'Pesan gagal dan tombol coba lagi',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2SemaianListPage.error(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.sprout,
                        title: 'Semaian kosong (5.5)',
                        subtitle: 'Belum ada semaian tercatat',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2SemaianListPage.empty(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.check,
                        title: 'Semaian selesai (5.6)',
                        subtitle: 'Baris selesai memudar',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2SemaianListPage.selesai(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.sprout,
                        title: 'Tambah semaian (5.7)',
                        subtitle: 'Isian tanggal, benih, dan bahan',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2SemaianFormPage.create(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.calendar,
                        title: 'Pilih tanggal (5.8)',
                        subtitle: 'Sheet kalender bulanan',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) =>
                              const V2SemaianFormPage.pilihTanggal(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.info,
                        title: 'Tambah semaian, keyboard (5.9)',
                        subtitle: 'Kolom jumlah terfokus',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2SemaianFormPage.keyboard(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.warning,
                        title: 'Tambah semaian, validasi (5.10)',
                        subtitle: 'Jumlah benih dan bahan kosong',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2SemaianFormPage.validation(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.warning,
                        title: 'Stok tidak cukup (5.11)',
                        subtitle: 'Jumlah bahan melebihi stok',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2SemaianFormPage.stokKurang(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.check,
                        title: 'Semaian ditambahkan (5.12)',
                        subtitle: 'Baris baru di paling atas',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2SemaianListPage.ditambahkan(),
                        ),
                        iconTone: V2ListItemIconTone.success,
                      ),
                      _FlowRow(
                        icon: V2IconName.sync,
                        title: 'Semaian menunggu sinkron (5.13)',
                        subtitle: 'Banner offline dan lencana antrean',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2SemaianListPage.offline(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.layers,
                        title: 'Pindah ke meja (5.17)',
                        subtitle: 'Pilih meja, jumlah, dan tanggal',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2PindahMejaFormPage.form(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.check,
                        title: 'Pindah berhasil (5.18)',
                        subtitle: '200 tanaman pindah ke Meja A2',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2PindahMejaResultPage.berhasil(),
                        ),
                        iconTone: V2ListItemIconTone.success,
                      ),
                      _FlowRow(
                        icon: V2IconName.warning,
                        title: 'Tidak ada meja kosong (5.20)',
                        subtitle: 'Ajakan menambah meja',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) =>
                              const V2PindahMejaResultPage.tidakAdaMeja(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.warning,
                        title: 'Pindah, lubang kurang (5.21)',
                        subtitle: 'Meja A3 hanya 120 lubang',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2PindahMejaFormPage.lubangKurang(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.check,
                        title: 'Pindah sebagian (5.22)',
                        subtitle: '120 pindah, 80 masih di semaian',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2PindahMejaResultPage.sebagian(),
                        ),
                        iconTone: V2ListItemIconTone.success,
                      ),
                      _FlowRow(
                        icon: V2IconName.layers,
                        title: 'Pindah sisa (5.24)',
                        subtitle: 'Sisa 80 benih ke Meja A2',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2PindahMejaFormPage.sisa(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.sprout,
                        title: 'Detail semaian baru (5.14)',
                        subtitle: 'HSS 0, linimasa berjalan',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2SemaianDetailPage.baru(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.sprout,
                        title: 'Detail semaian (5.15)',
                        subtitle: 'Butterhead berjalan, HSS 10',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2SemaianDetailPage.biasa(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.check,
                        title: 'Detail siap pindah (5.16)',
                        subtitle: 'Banner hijau dan tombol pindah',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2SemaianDetailPage.siapPindah(),
                        ),
                        iconTone: V2ListItemIconTone.success,
                      ),
                      _FlowRow(
                        icon: V2IconName.check,
                        title: 'Detail siap pindah, ada sisa (5.23)',
                        subtitle: '120 pindah, sisa 80 benih',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2SemaianDetailPage.sisa(),
                        ),
                        iconTone: V2ListItemIconTone.success,
                      ),
                      _FlowRow(
                        icon: V2IconName.info,
                        title: 'Detail semaian selesai (5.30)',
                        subtitle: 'Tanpa tombol, tumbuh di Meja A2',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2SemaianDetailPage.selesai(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.check,
                        title: 'Detail dipindah semua (5.19)',
                        subtitle: '200 benih pindah ke Meja A2',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2SemaianDetailPage.dipindahSemua(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.info,
                        title: 'Detail selesai, ada sisa (5.29)',
                        subtitle: '120 pindah, 80 tidak dipindah',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2SemaianDetailPage.selesaiSisa(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.edit,
                        title: 'Ubah semaian (5.25)',
                        subtitle: 'Butterhead 150 benih, Rak 2, aktif',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2SemaianEditPage.butterhead(),
                        ),
                        iconTone: V2ListItemIconTone.blue,
                      ),
                      _FlowRow(
                        icon: V2IconName.edit,
                        title: 'Ubah semaian Romaine (5.27)',
                        subtitle: '200 benih, Rak 2, aktif',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2SemaianEditPage.romaine(),
                        ),
                        iconTone: V2ListItemIconTone.blue,
                      ),
                      _FlowRow(
                        icon: V2IconName.check,
                        title: 'Perubahan tersimpan (5.26)',
                        subtitle: 'Detail Butterhead 140 benih dan toast',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2SemaianDetailPage.tersimpan(),
                        ),
                        iconTone: V2ListItemIconTone.success,
                      ),
                      _FlowRow(
                        icon: V2IconName.warning,
                        title: 'Tandai selesai (5.28)',
                        subtitle: 'Dialog destruktif sisa 80 benih',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2SemaianEditPage.tandaiSelesai(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.sync,
                        title: 'Data sudah berubah (5.31)',
                        subtitle: 'Dialog muat ulang karena bentrok',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2SemaianEditPage.konflik(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
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
