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
import 'v2_meja_detail_page.dart';
import 'v2_meja_form_page.dart';
import 'v2_meja_list_page.dart';
import 'v2_panen_detail_page.dart';
import 'v2_panen_edit_page.dart';
import 'v2_panen_form_page.dart';
import 'v2_panen_list_page.dart';
import 'v2_pilih_semaian_page.dart';
import 'v2_rawat_detail_page.dart';
import 'v2_rawat_foto_page.dart';
import 'v2_rawat_hasil_page.dart';
import 'v2_rawat_konfirmasi_page.dart';
import 'v2_rawat_list_page.dart';
import 'v2_rawat_obat_page.dart';
import 'v2_cuaca_page.dart';
import 'v2_tanaman_rusak_page.dart';
import 'v2_detail_tanaman_page.dart';
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
                        icon: V2IconName.layers,
                        title: 'Meja tanam (06)',
                        subtitle: 'Daftar meja, detail lubang, dan tanaman',
                        route: V2MejaListPage.route,
                      ),
                      _FlowRow(
                        icon: V2IconName.sprout,
                        title: 'Panen (07)',
                        subtitle: 'Estimasi, catat panen, riwayat, detail',
                        route: V2PanenListPage.route,
                      ),
                      _FlowRow(
                        icon: V2IconName.care,
                        title: 'Perawatan (09)',
                        subtitle: 'Cek hama, hasil deteksi, obat, riwayat',
                        route: V2RawatListPage.route,
                      ),
                      _FlowRow(
                        icon: V2IconName.sun,
                        title: 'Cuaca (10)',
                        subtitle: 'Kondisi, prakiraan, saran, pilih lokasi',
                        route: V2CuacaPage.route,
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
                      _FlowRow(
                        icon: V2IconName.user,
                        title: 'Meja tanam pegawai (6.2)',
                        subtitle: 'Tab bar peran pegawai',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2MejaListPage.pegawai(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.layers,
                        title: 'Meja memuat (6.3)',
                        subtitle: 'Empat rangka kartu sebelum daftar',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2MejaListPage.memuat(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.warning,
                        title: 'Meja gagal memuat (6.4)',
                        subtitle: 'Pesan gagal dan tombol coba lagi',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2MejaListPage.gagal(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.layers,
                        title: 'Meja kosong (6.5)',
                        subtitle: 'Belum ada meja, tombol tambah meja',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2MejaListPage.kosong(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.plus,
                        title: 'Tambah meja (6.6)',
                        subtitle: 'Kode meja, jumlah lubang, keterangan',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2MejaFormPage.create(),
                        ),
                      ),
                      _FlowRow(
                        icon: V2IconName.error,
                        title: 'Tambah meja, validasi (6.7)',
                        subtitle: 'Kode sudah dipakai dan jumlah 0',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2MejaFormPage.validation(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.check,
                        title: 'Meja ditambahkan (6.8)',
                        subtitle: 'Meja C1 di atas daftar dan toast',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2MejaListPage.ditambahkan(),
                        ),
                        iconTone: V2ListItemIconTone.success,
                      ),
                      _FlowRow(
                        icon: V2IconName.cloud,
                        title: 'Tersimpan di HP (6.9)',
                        subtitle: 'Banner offline dan baris antrean',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2MejaListPage.offline(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.layers,
                        title: 'Detail meja kosong (6.10)',
                        subtitle: 'Meja C1, 0 dari 180 lubang',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2MejaDetailPage.kosong(),
                        ),
                      ),
                      _FlowRow(
                        icon: V2IconName.layers,
                        title: 'Detail meja (6.11)',
                        subtitle: 'Meja A2, 40 dari 240, satu tanaman',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2MejaDetailPage.biasa(),
                        ),
                      ),
                      _FlowRow(
                        icon: V2IconName.sync,
                        title: 'Ubah status meja (6.12)',
                        subtitle: 'Sheet Tersedia, Perawatan, Penuh',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2MejaDetailPage.statusSheet(),
                        ),
                        iconTone: V2ListItemIconTone.blue,
                      ),
                      _FlowRow(
                        icon: V2IconName.care,
                        title: 'Status diubah (6.13)',
                        subtitle: 'Meja perawatan dan toast',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2MejaDetailPage.status(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.sprout,
                        title: 'Pilih semaian (6.14)',
                        subtitle: 'Semaian HSS 15 siap pindah',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2PilihSemaianPage.siap(),
                        ),
                      ),
                      _FlowRow(
                        icon: V2IconName.sprout,
                        title: 'Belum ada semaian siap (6.15)',
                        subtitle: 'Ilustrasi dan tombol lihat semaian',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2PilihSemaianPage.kosong(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.layers,
                        title: 'Detail meja penuh (6.16)',
                        subtitle: '240 dari 240, dua tanaman',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2MejaDetailPage.penuh(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.check,
                        title: 'Detail meja siap panen (6.17)',
                        subtitle: 'Meja B1, panen hari ini',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2MejaDetailPage.siapPanen(),
                        ),
                        iconTone: V2ListItemIconTone.success,
                      ),
                      _FlowRow(
                        icon: V2IconName.edit,
                        title: 'Ubah meja (6.18)',
                        subtitle: 'Meja A2, 240 lubang, catatan status',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2MejaFormPage.ubah(),
                        ),
                      ),
                      _FlowRow(
                        icon: V2IconName.error,
                        title: 'Ubah meja, lubang kurang (6.19)',
                        subtitle: '30 lubang, minimal 40',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2MejaFormPage.lubangKurang(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.check,
                        title: 'Meja diubah (6.20)',
                        subtitle: 'Detail meja dan toast tersimpan',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2MejaDetailPage.diubah(),
                        ),
                        iconTone: V2ListItemIconTone.success,
                      ),
                      _FlowRow(
                        icon: V2IconName.sprout,
                        title: 'Detail tanaman (6.21)',
                        subtitle: 'Romaine Meja A2, HST 8, panen 22 Des',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2DetailTanamanPage.biasa(),
                        ),
                      ),
                      _FlowRow(
                        icon: V2IconName.edit,
                        title: 'Ubah catatan tanaman (6.22)',
                        subtitle: 'Keterangan rak bawah',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2UbahCatatanTanamanPage.biasa(),
                        ),
                      ),
                      _FlowRow(
                        icon: V2IconName.check,
                        title: 'Catatan tersimpan (6.23)',
                        subtitle: 'Detail tanaman dan toast',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2DetailTanamanPage.tersimpan(),
                        ),
                        iconTone: V2ListItemIconTone.success,
                      ),
                      _FlowRow(
                        icon: V2IconName.warning,
                        title: 'Daftar rusak (6.24)',
                        subtitle: 'Satu catatan busuk akar',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2TanamanRusakPage.biasa(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.plus,
                        title: 'Catat rusak (6.25)',
                        subtitle: 'Tanggal, jumlah, jenis, keterangan',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2CatatRusakPage.catat(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.error,
                        title: 'Catat rusak, validasi (6.26)',
                        subtitle: '45 tanaman dan jenis belum dipilih',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2CatatRusakPage.validation(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.check,
                        title: 'Kerusakan dicatat (6.27)',
                        subtitle: 'Layu 15 Nov di atas busuk akar',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2TanamanRusakPage.setelahCatat(),
                        ),
                        iconTone: V2ListItemIconTone.success,
                      ),
                      _FlowRow(
                        icon: V2IconName.edit,
                        title: 'Ubah kerusakan (6.28)',
                        subtitle: 'Busuk akar 10 Nov dengan catatan',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2CatatRusakPage.ubah(),
                        ),
                        iconTone: V2ListItemIconTone.blue,
                      ),
                      _FlowRow(
                        icon: V2IconName.check,
                        title: 'Kerusakan diubah (6.29)',
                        subtitle: 'Daftar rusak dan toast',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2TanamanRusakPage.diubah(),
                        ),
                        iconTone: V2ListItemIconTone.success,
                      ),
                      _FlowRow(
                        icon: V2IconName.sync,
                        title: 'Data sudah berubah (6.30)',
                        subtitle: 'Dialog konflik di atas form ubah',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2MejaFormPage.konflik(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.user,
                        title: 'Panen, estimasi pegawai (7.2)',
                        subtitle: 'Tab bar peran pegawai',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2PanenListPage.pegawai(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.sprout,
                        title: 'Panen, estimasi (7.1)',
                        subtitle: 'Meja B1 siap panen hari ini',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2PanenListPage.petani(),
                        ),
                        iconTone: V2ListItemIconTone.blue,
                      ),
                      _FlowRow(
                        icon: V2IconName.layers,
                        title: 'Panen memuat (7.3)',
                        subtitle: 'Empat rangka kartu sebelum daftar',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2PanenListPage.memuat(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.warning,
                        title: 'Panen gagal memuat (7.4)',
                        subtitle: 'Pesan gagal dan tombol coba lagi',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2PanenListPage.gagal(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.layers,
                        title: 'Belum ada tanaman (7.5)',
                        subtitle: 'Ilustrasi meja dan tombol lihat semaian',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2PanenListPage.kosong(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.chart,
                        title: 'Riwayat panen (7.6)',
                        subtitle: 'Grafik berat layak dan panen 6 Nov',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2PanenListPage.riwayat(),
                        ),
                        iconTone: V2ListItemIconTone.blue,
                      ),
                      _FlowRow(
                        icon: V2IconName.chart,
                        title: 'Riwayat panen kosong (7.7)',
                        subtitle: 'Ilustrasi dan tombol catat panen',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2PanenListPage.riwayatKosong(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.plus,
                        title: 'Catat panen (7.8)',
                        subtitle: 'Meja B1, 240 tanaman, 270/18 kg',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2PanenFormPage.catat(),
                        ),
                        iconTone: V2ListItemIconTone.blue,
                      ),
                      _FlowRow(
                        icon: V2IconName.layers,
                        title: 'Pilih tanaman (7.9)',
                        subtitle: 'Sheet tiga pilihan meja',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2PanenFormPage.tanamanSheet(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.edit,
                        title: 'Catat panen, keyboard (7.10)',
                        subtitle: 'Dua isian berat di atas keyboard',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2PanenFormPage.keyboard(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.warning,
                        title: 'Catat panen, validasi (7.11)',
                        subtitle: 'Tanaman belum dipilih, berat kosong',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2PanenFormPage.validation(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.warning,
                        title: 'Jumlah melebihi tanaman (7.12)',
                        subtitle: '300 dari 240 tanaman aktif',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2PanenFormPage.melebihi(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.check,
                        title: 'Panen dicatat (7.13)',
                        subtitle: '252 kg layak dari Meja B1',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2PanenSavedPage(),
                        ),
                        iconTone: V2ListItemIconTone.success,
                      ),
                      _FlowRow(
                        icon: V2IconName.sprout,
                        title: 'Detail panen baru (7.14)',
                        subtitle: 'Panen 15 Nov, belum terjual',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2PanenDetailPage.baru(),
                        ),
                        iconTone: V2ListItemIconTone.blue,
                      ),
                      _FlowRow(
                        icon: V2IconName.sprout,
                        title: 'Tersimpan di HP (7.15)',
                        subtitle: 'Banner offline dan baris antrean',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2PanenListPage.offline(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.sync,
                        title: 'Detail panen antrean (7.16)',
                        subtitle: 'Catat penjualan menunggu sinkron',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2PanenDetailPage.antrean(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.sprout,
                        title: 'Detail panen (7.17)',
                        subtitle: 'Panen 6 Nov, terjual sebagian',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2PanenDetailPage.biasa(),
                        ),
                        iconTone: V2ListItemIconTone.blue,
                      ),
                      _FlowRow(
                        icon: V2IconName.user,
                        title: 'Detail panen pegawai (7.18)',
                        subtitle: 'Hanya tombol ubah',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2PanenDetailPage.pegawai(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.edit,
                        title: 'Ubah panen (7.19)',
                        subtitle: '255/15 kg dan catatan panen pagi',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2PanenEditPage.biasa(),
                        ),
                        iconTone: V2ListItemIconTone.blue,
                      ),
                      _FlowRow(
                        icon: V2IconName.warning,
                        title: 'Berat di bawah terjual (7.20)',
                        subtitle: 'Layak 80 kg, terjual 90 kg',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2PanenEditPage.bawahTerjual(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.check,
                        title: 'Perubahan tersimpan (7.21)',
                        subtitle: 'Detail panen dan toast',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2PanenDetailPage.tersimpan(),
                        ),
                        iconTone: V2ListItemIconTone.success,
                      ),
                      _FlowRow(
                        icon: V2IconName.warning,
                        title: 'Buang perubahan (7.22)',
                        subtitle: 'Dialog di atas form terisi',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2PanenFormPage.buang(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.sync,
                        title: 'Data sudah berubah (7.23)',
                        subtitle: 'Dialog konflik di atas form ubah',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2PanenEditPage.konflik(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.care,
                        title: 'Rawat (9.1)',
                        subtitle: 'Cek hama, cuaca, riwayat perawatan',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2RawatListPage.petani(),
                        ),
                        iconTone: V2ListItemIconTone.blue,
                      ),
                      _FlowRow(
                        icon: V2IconName.layers,
                        title: 'Memuat rawat (9.2)',
                        subtitle: 'Empat rangka baris sebelum daftar',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2RawatListPage.memuat(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.warning,
                        title: 'Gagal memuat rawat (9.3)',
                        subtitle: 'Pesan gagal dan tombol coba lagi',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2RawatListPage.gagal(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.care,
                        title: 'Belum ada perawatan (9.4)',
                        subtitle: 'Ilustrasi dan ajakan foto daun',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2RawatListPage.kosong(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.camera,
                        title: 'Tips foto (9.5)',
                        subtitle: 'Tiga tips foto daun yang bagus',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2RawatFotoPage.tips(),
                        ),
                        iconTone: V2ListItemIconTone.blue,
                      ),
                      _FlowRow(
                        icon: V2IconName.camera,
                        title: 'Izin kamera (9.6)',
                        subtitle: 'Minta izin sebelum membuka kamera',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2RawatFotoPage.izin(),
                        ),
                        iconTone: V2ListItemIconTone.blue,
                      ),
                      _FlowRow(
                        icon: V2IconName.warning,
                        title: 'Izin kamera ditolak (9.7)',
                        subtitle: 'Buka pengaturan atau pilih galeri',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2RawatFotoPage.izinDitolak(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.camera,
                        title: 'Kamera (9.8)',
                        subtitle: 'Bingkai 310 dan tombol rana 88',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2RawatFotoPage.kamera(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.sprout,
                        title: 'Pratinjau foto (9.9)',
                        subtitle: 'Foto 240 dan pilihan tanaman',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2RawatFotoPage.pratinjau(),
                        ),
                        iconTone: V2ListItemIconTone.blue,
                      ),
                      _FlowRow(
                        icon: V2IconName.cloud,
                        title: 'Foto tanpa internet (9.10)',
                        subtitle: 'Banner offline dan simpan foto',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2RawatFotoPage.tanpaInternet(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.camera,
                        title: 'Foto tersimpan (9.11)',
                        subtitle: 'Baris foto menunggu analisis',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2RawatListPage.fotoTersimpan(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.sync,
                        title: 'Mengunggah foto (9.12)',
                        subtitle: 'Tombol mengunggah tanpa batal',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2RawatFotoPage.unggah(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.sync,
                        title: 'Menganalisis foto (9.13)',
                        subtitle: 'Tombol batal dan ilustrasi tanaman',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2RawatFotoPage.analisis(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.warning,
                        title: 'Hasil: hama ditemukan (9.14)',
                        subtitle: 'Thrips 87%, saran lihat obat',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2RawatHasilPage.hama(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.warning,
                        title: 'Hasil: beberapa hama (9.15)',
                        subtitle: 'Thrips dan kutu daun',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2RawatHasilPage.beberapa(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.info,
                        title: 'Hasil: keyakinan rendah (9.16)',
                        subtitle: '42%, mungkin Thrips',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2RawatHasilPage.rendah(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.check,
                        title: 'Hasil: tanaman sehat (9.17)',
                        subtitle: 'Keyakinan 93%, pantau lagi',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2RawatHasilPage.sehat(),
                        ),
                        iconTone: V2ListItemIconTone.success,
                      ),
                      _FlowRow(
                        icon: V2IconName.warning,
                        title: 'Analisis gagal (9.18)',
                        subtitle: 'Foto tetap tersimpan, coba lagi',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2RawatHasilPage.gagal(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.care,
                        title: 'Rekomendasi obat Thrips (9.19)',
                        subtitle: 'Rotasi dari Sabun insektisida',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2RawatObatPage.thrips(),
                        ),
                        iconTone: V2ListItemIconTone.blue,
                      ),
                      _FlowRow(
                        icon: V2IconName.care,
                        title: 'Rekomendasi obat Kutu daun (9.20)',
                        subtitle: 'Rotasi dari Obat Nabati',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2RawatObatPage.kutuDaun(),
                        ),
                        iconTone: V2ListItemIconTone.blue,
                      ),
                      _FlowRow(
                        icon: V2IconName.check,
                        title: 'Konfirmasi perawatan (9.21)',
                        subtitle: '1 botol Obat Nabati, stok berkurang',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2RawatKonfirmasiPage.biasa(),
                        ),
                        iconTone: V2ListItemIconTone.blue,
                      ),
                      _FlowRow(
                        icon: V2IconName.warning,
                        title: 'Stok obat kurang (9.22)',
                        subtitle: '2 botol, stok hanya 1',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) =>
                              const V2RawatKonfirmasiPage.stokKurang(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.check,
                        title: 'Perawatan dicatat (9.23)',
                        subtitle: 'Tersimpan, cek lagi dalam 3 hari',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2RawatSavedPage(),
                        ),
                        iconTone: V2ListItemIconTone.success,
                      ),
                      _FlowRow(
                        icon: V2IconName.sprout,
                        title: 'Detail perawatan baru (9.24)',
                        subtitle: '15 Nov, Obat Nabati 1 botol',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2RawatDetailPage.baru(),
                        ),
                        iconTone: V2ListItemIconTone.blue,
                      ),
                      _FlowRow(
                        icon: V2IconName.sync,
                        title: 'Tersimpan di HP (9.25)',
                        subtitle: 'Banner offline dan baris antrean',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2RawatListPage.tersimpanHp(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.sync,
                        title: 'Detail perawatan antrean (9.26)',
                        subtitle: 'Belum di server, saran AI',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2RawatDetailPage.antrean(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.sprout,
                        title: 'Detail perawatan 12 Nov (9.27)',
                        subtitle: 'Sabun insektisida, keyakinan 87%',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => V2RawatDetailPage.lama(),
                        ),
                        iconTone: V2ListItemIconTone.blue,
                      ),
                      _FlowRow(
                        icon: V2IconName.warning,
                        title: 'Buang perubahan (9.28)',
                        subtitle: 'Dialog di atas form konfirmasi',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2RawatKonfirmasiPage.buang(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.sun,
                        title: 'Cuaca, kondisi (10.1)',
                        subtitle: 'Suhu 29°C, kelembapan, hujan',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2CuacaPage.kondisi(),
                        ),
                        iconTone: V2ListItemIconTone.blue,
                      ),
                      _FlowRow(
                        icon: V2IconName.cloud,
                        title: 'Cuaca, prakiraan (10.2)',
                        subtitle: 'Empat hari ke depan',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2CuacaPage.prakiraan(),
                        ),
                        iconTone: V2ListItemIconTone.blue,
                      ),
                      _FlowRow(
                        icon: V2IconName.care,
                        title: 'Saran perawatan (10.3)',
                        subtitle: 'Tiga saran dari cuaca',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2CuacaPage.saran(),
                        ),
                        iconTone: V2ListItemIconTone.blue,
                      ),
                      _FlowRow(
                        icon: V2IconName.info,
                        title: 'Saran kosong (10.4)',
                        subtitle: 'Tidak ada saran khusus',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2CuacaPage.saranKosong(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.layers,
                        title: 'Pilih lokasi (10.5)',
                        subtitle: 'Sheet tiga lokasi',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2CuacaPage.pilihLokasi(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.layers,
                        title: 'Memuat cuaca (10.6)',
                        subtitle: 'Tiga rangka kartu',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2CuacaPage.memuat(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.warning,
                        title: 'BMKG tidak tersedia (10.7)',
                        subtitle: 'ErrorState dan coba lagi',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2CuacaPage.bmkgGagal(),
                        ),
                        iconTone: V2ListItemIconTone.warning,
                      ),
                      _FlowRow(
                        icon: V2IconName.sync,
                        title: 'Cuaca tanpa internet (10.8)',
                        subtitle: 'Data terakhir 14.05',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2CuacaPage.tanpaInternet(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.sync,
                        title: 'Prakiraan tanpa internet (10.9)',
                        subtitle: 'Empat hari dari HP',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) =>
                              const V2CuacaPage.prakiraanTanpaInternet(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.sync,
                        title: 'Saran tanpa internet (10.10)',
                        subtitle: 'Saran butuh internet',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2CuacaPage.saranTanpaInternet(),
                        ),
                        iconTone: V2ListItemIconTone.neutral,
                      ),
                      _FlowRow(
                        icon: V2IconName.warning,
                        title: 'Saran AI tidak tersedia (10.11)',
                        subtitle: 'Kartu coba lagi',
                        route: () => MaterialPageRoute<void>(
                          builder: (_) => const V2CuacaPage.saranGagal(),
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
