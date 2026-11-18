import 'package:flutter/material.dart';

import '../components/v2_akun_employee.dart';
import '../components/v2_akun_employee_store.dart';
import '../components/v2_beranda_hero.dart';
import '../components/v2_beranda_skeleton.dart';
import '../components/v2_beranda_stats.dart';
import '../theme/v2_tokens.dart';
import '../v2_roles.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_banner.dart';
import '../widgets/v2_checklist.dart';
import '../widgets/v2_dialog.dart';
import '../widgets/v2_icon.dart';
import '../widgets/v2_icon_button.dart';
import '../widgets/v2_list_item.dart';
import '../widgets/v2_tab_bar.dart';
import 'v2_akun_tab_page.dart';
import 'v2_cycle_detail_page.dart';
import 'v2_employee_list_page.dart';
import 'v2_notifications_page.dart';
import 'v2_penjualan_list_page.dart';
import 'v2_sinkron_page.dart';

/// Peran pengguna dipakai lewat `v2_roles.dart`; di-ekspor ulang di sini supaya
/// pemanggil lama (`app_gate.dart`) tetap menemukannya di halaman beranda.
export '../v2_roles.dart' show V2BerandaRole;

/// Keadaan beranda yang punya frame sendiri di page 02.
enum V2BerandaState {
  /// Frame 2.1/2.2: data siap.
  ready,

  /// Frame 2.3: rangka kartu sebelum 2.1 tampil.
  loading,

  /// Frame 2.5: perangkat sedang offline, ada antrean sinkron.
  offline,

  /// Frame 2.6: layanan BMKG gagal, kartu cuaca menawarkan coba lagi.
  weatherUnavailable,
}

/// Beranda dari frame `2.1 Beranda (Petani)` sampai `2.6 BMKG tidak tersedia`.
///
/// Susunan siap: sapaan + bel (buka 2.4), kartu hero siklus (buka 2.7), baris
/// "Siap pindah", dua petak statistik, lalu kartu cuaca (khusus Petani).
/// Keadaan memuat, offline, dan BMKG gagal memakai susunan yang sama dengan
/// penyesuaian sesuai catatan alur tiap frame.
///
/// Tab terakhir juga memuat alur page 03 "Akun": Petani membuka "Lainnya"
/// (frame 3.1) dengan menu kelola akun pegawai, Pegawai membuka "Profil"
/// (frame 3.2) yang hanya bisa dibaca. Tab lain masih placeholder.
class V2BerandaPage extends StatefulWidget {
  const V2BerandaPage({
    super.key,
    this.userName = 'Budi',
    this.fullName = 'Budi Santoso',
    this.username = 'sari.dewi',
    this.phone = '0812 3456 7890',
    this.address = 'Jl. Melati 12, Malang',
    this.role = V2BerandaRole.petani,
    this.state = V2BerandaState.ready,
    this.siapPindahSubtitle = '1 semaian, HSS 17',
    this.lowStock = '2',
    this.filledHoles = '400',
    this.weatherTitle = 'Berawan, 29°C',
    this.weatherSubtitle = 'Hujan 14.00',
    this.initialEmployees = designEmployees,
    this.employeeStore,
    this.onLowStock,
    this.onOpenNotifications,
    this.onLogOut,
  });

  /// Frame `2.3 Beranda memuat`.
  const V2BerandaPage.loading({
    super.key,
    this.userName = 'Budi',
    this.fullName = 'Budi Santoso',
    this.username = 'sari.dewi',
    this.phone = '0812 3456 7890',
    this.address = 'Jl. Melati 12, Malang',
    this.role = V2BerandaRole.petani,
    this.initialEmployees = designEmployees,
    this.onLowStock,
    this.onOpenNotifications,
    this.onLogOut,
  }) : employeeStore = null,
       state = V2BerandaState.loading,
       siapPindahSubtitle = '1 semaian, HSS 17',
       lowStock = '2',
       filledHoles = '400',
       weatherTitle = 'Berawan, 29°C',
       weatherSubtitle = 'Hujan 14.00';

  /// Frame `2.5 Offline dan antrean sinkron`.
  const V2BerandaPage.offline({
    super.key,
    this.userName = 'Budi',
    this.fullName = 'Budi Santoso',
    this.username = 'sari.dewi',
    this.phone = '0812 3456 7890',
    this.address = 'Jl. Melati 12, Malang',
    this.role = V2BerandaRole.petani,
    this.initialEmployees = designEmployees,
    this.onLowStock,
    this.onOpenNotifications,
    this.onLogOut,
  }) : employeeStore = null,
       state = V2BerandaState.offline,
       siapPindahSubtitle = '2 semaian, HSS 15',
       lowStock = '3',
       filledHoles = '184',
       weatherTitle = 'Berawan, 29°C',
       weatherSubtitle = 'Hujan 14.00';

  /// Frame `2.6 BMKG tidak tersedia`.
  const V2BerandaPage.weatherUnavailable({
    super.key,
    this.userName = 'Budi',
    this.fullName = 'Budi Santoso',
    this.username = 'sari.dewi',
    this.phone = '0812 3456 7890',
    this.address = 'Jl. Melati 12, Malang',
    this.role = V2BerandaRole.petani,
    this.initialEmployees = designEmployees,
    this.onLowStock,
    this.onOpenNotifications,
    this.onLogOut,
  }) : employeeStore = null,
       state = V2BerandaState.weatherUnavailable,
       siapPindahSubtitle = '2 semaian, HSS 15',
       lowStock = '3',
       filledHoles = '184',
       weatherTitle = 'Berawan, 29°C',
       weatherSubtitle = 'Hujan 14.00';

  final String userName;

  /// Nama lengkap untuk kartu Profil di tab "Lainnya"/"Profil".
  final String fullName;
  final String username;
  final String phone;
  final String address;
  final V2BerandaRole role;
  final V2BerandaState state;
  final String siapPindahSubtitle;
  final String lowStock;
  final String filledHoles;

  /// Teks kartu cuaca (frame 2.1/2.2); diisi data BMKG saat beranda tersambung.
  final String weatherTitle;
  final String weatherSubtitle;

  /// Daftar akun pegawai (alur 03). Disimpan di sini supaya tetap utuh saat
  /// berpindah tab, lalu diteruskan ke halaman daftar/ubah.
  final List<V2Employee> initialEmployees;

  /// Backend akun pegawai; null berarti galeri memakai [initialEmployees].
  final V2EmployeeStore? employeeStore;

  final VoidCallback? onLowStock;
  final VoidCallback? onOpenNotifications;

  /// Menutup sesi (frame 3.3); diisi oleh `AppGate`.
  final Future<void> Function()? onLogOut;


  static const String _tableName = 'Meja A2';

  static const List<V2TabItem> _petaniTabs = [
    V2TabItem(label: 'Beranda', icon: V2IconName.home),
    V2TabItem(label: 'Tanam', icon: V2IconName.sprout),
    V2TabItem(label: 'Stok', icon: V2IconName.box),
    V2TabItem(label: 'Rawat', icon: V2IconName.care),
    V2TabItem(label: 'Lainnya', icon: V2IconName.more),
  ];

  static const List<V2TabItem> _pegawaiTabs = [
    V2TabItem(label: 'Beranda', icon: V2IconName.home),
    V2TabItem(label: 'Tanam', icon: V2IconName.sprout),
    V2TabItem(label: 'Stok', icon: V2IconName.box),
    V2TabItem(label: 'Profil', icon: V2IconName.user),
  ];

  @override
  State<V2BerandaPage> createState() => _V2BerandaPageState();
}

class _V2BerandaPageState extends State<V2BerandaPage> {
  late V2BerandaState _state = widget.state;
  late List<V2Employee> _employees = widget.initialEmployees;
  int _activeTab = 0;

  @override
  void didUpdateWidget(V2BerandaPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) _state = widget.state;
    if (oldWidget.role != widget.role) _activeTab = 0;
  }

  bool get _petani => widget.role == V2BerandaRole.petani;

  /// Index tab "Lainnya" (Petani) atau "Profil" (Pegawai): tab terakhir.
  int get _akunIndex =>
      (_petani ? V2BerandaPage._petaniTabs : V2BerandaPage._pegawaiTabs)
          .length -
      1;

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _onTabTap(int index) {
    if (index == _akunIndex || index == 0) {
      setState(() => _activeTab = index);
      return;
    }
    _notice('Tab ${index + 1} alur v2 belum tersedia di halaman ini.');
  }

  void _openEmployees() {
    Navigator.of(context).push(
      V2EmployeeListPage.route(
        initialEmployees: _employees,
        onChanged: (employees) => setState(() => _employees = employees),
        store: widget.employeeStore,
      ),
    );
  }

  void _openSales() {
    Navigator.of(context).push(V2PenjualanListPage.route());
  }

  void _openSync() {
    Navigator.of(context).push(V2SinkronPage.route());
  }

  Future<void> _confirmLogOut() async {
    final confirmed = await showV2Dialog(
      context,
      title: 'Keluar dari akun?',
      body: 'Anda perlu masuk lagi.',
      primaryLabel: 'Keluar',
      secondaryLabel: 'Batal',
    );
    if (confirmed != true || !mounted) return;
    final onLogOut = widget.onLogOut;
    if (onLogOut == null) {
      _notice('Keluar akun belum terhubung di pratinjau ini.');
      return;
    }
    await onLogOut();
  }

  void _openNotifications() {
    if (widget.onOpenNotifications != null) {
      widget.onOpenNotifications!();
      return;
    }
    Navigator.of(context).push(
      V2NotificationsPage.route(
        onMarkAllRead: () {
          Navigator.of(context).maybePop();
          _notice('Semua notifikasi ditandai sudah dibaca.');
        },
      ),
    );
  }

  void _openCycle() {
    Navigator.of(context).push(
      V2CycleDetailPage.route(
        tableName: V2BerandaPage._tableName,
        onOpenTable: () =>
            _notice('Alur Meja A2 6.11 belum tersedia di halaman ini.'),
      ),
    );
  }

  void _retryWeather() => setState(() => _state = V2BerandaState.ready);

  @override
  Widget build(BuildContext context) {
    final tabs = _petani ? V2BerandaPage._petaniTabs : V2BerandaPage._pegawaiTabs;
    final akun = _activeTab == _akunIndex;
    return Theme(
      data: V2Theme.light,
      child: Scaffold(
        backgroundColor: V2Colors.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: akun
                    ? V2AkunTabView(
                        role: widget.role,
                        userName: widget.fullName,
                        username: widget.username,
                        phone: widget.phone,
                        address: widget.address,
                        onOpenEmployees: _petani ? _openEmployees : null,
                        onOpenSales: _petani ? _openSales : null,
                        onOpenSync: _openSync,
                        onLogOut: _confirmLogOut,
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          V2Space.xl,
                          V2Space.lg,
                          V2Space.xl,
                          V2Space.lg,
                        ),
                        child: _content(),
                      ),
              ),
              V2TabBar(
                items: tabs,
                activeIndex: _activeTab,
                onTap: _onTabTap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content() {
    if (_state == V2BerandaState.loading) {
      return V2BerandaSkeleton(withWeather: _petani);
    }

    final offline = _state == V2BerandaState.offline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        V2ScreenHeader(
          title: 'Halo, ${widget.userName}',
          trailing: V2IconButton(
            icon: V2IconName.bell,
            onPressed: _openNotifications,
            semanticLabel: 'Notifikasi',
          ),
        ),
        const SizedBox(height: V2Space.lg),
        if (offline) ...[
          const V2Banner(message: 'Offline. 3 data menunggu sinkron.'),
          const SizedBox(height: V2Space.lg),
        ],
        V2BerandaHero(onTap: _openCycle),
        const SizedBox(height: V2Space.lg),
        V2ListItem(
          icon: V2IconName.sprout,
          title: 'Siap pindah',
          subtitle: widget.siapPindahSubtitle,
          onTap: () => _notice('Alur semaian 5.16 belum tersedia di halaman ini.'),
        ),
        const SizedBox(height: V2Space.lg),
        V2BerandaStats(
          lowStock: widget.lowStock,
          filledHoles: widget.filledHoles,
          onLowStock: widget.onLowStock ?? () => _notice('Stok menipis 4.9.'),
        ),
        if (_petani) ...[
          const SizedBox(height: V2Space.lg),
          if (_state == V2BerandaState.weatherUnavailable)
            V2WeatherCard(
              title: 'Cuaca BMKG',
              subtitle: 'Tidak tersedia',
              state: V2WeatherCardState.unavailable,
              onRetry: _retryWeather,
            )
          else
            V2WeatherCard(
              title: widget.weatherTitle,
              subtitle: widget.weatherSubtitle,
              onTap: () => _notice('Halaman cuaca BMKG (10) belum tersedia.'),
            ),
        ],
      ],
    );
  }
}
