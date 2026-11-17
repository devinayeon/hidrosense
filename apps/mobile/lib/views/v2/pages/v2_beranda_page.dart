import 'package:flutter/material.dart';

import '../components/v2_beranda_hero.dart';
import '../components/v2_beranda_skeleton.dart';
import '../components/v2_beranda_stats.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_banner.dart';
import '../widgets/v2_checklist.dart';
import '../widgets/v2_icon.dart';
import '../widgets/v2_icon_button.dart';
import '../widgets/v2_list_item.dart';
import '../widgets/v2_tab_bar.dart';
import 'v2_cycle_detail_page.dart';
import 'v2_notifications_page.dart';

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

/// Peran pengguna: hanya Petani yang melihat kartu cuaca (2.1 vs 2.2).
enum V2BerandaRole { petani, pegawai }

/// Beranda dari frame `2.1 Beranda (Petani)` sampai `2.6 BMKG tidak tersedia`.
///
/// Susunan siap: sapaan + bel (buka 2.4), kartu hero siklus (buka 2.7), baris
/// "Siap pindah", dua petak statistik, lalu kartu cuaca (khusus Petani).
/// Keadaan memuat, offline, dan BMKG gagal memakai susunan yang sama dengan
/// penyesuaian sesuai catatan alur tiap frame.
class V2BerandaPage extends StatefulWidget {
  const V2BerandaPage({
    super.key,
    this.userName = 'Budi',
    this.role = V2BerandaRole.petani,
    this.state = V2BerandaState.ready,
    this.siapPindahSubtitle = '1 semaian, HSS 17',
    this.lowStock = '2',
    this.filledHoles = '400',
    this.onLowStock,
    this.onOpenNotifications,
  });

  /// Frame `2.3 Beranda memuat`.
  const V2BerandaPage.loading({
    super.key,
    this.userName = 'Budi',
    this.role = V2BerandaRole.petani,
    this.onLowStock,
    this.onOpenNotifications,
  }) : state = V2BerandaState.loading,
       siapPindahSubtitle = '1 semaian, HSS 17',
       lowStock = '2',
       filledHoles = '400';

  /// Frame `2.5 Offline dan antrean sinkron`.
  const V2BerandaPage.offline({
    super.key,
    this.userName = 'Budi',
    this.role = V2BerandaRole.petani,
    this.onLowStock,
    this.onOpenNotifications,
  }) : state = V2BerandaState.offline,
       siapPindahSubtitle = '2 semaian, HSS 15',
       lowStock = '3',
       filledHoles = '184';

  /// Frame `2.6 BMKG tidak tersedia`.
  const V2BerandaPage.weatherUnavailable({
    super.key,
    this.userName = 'Budi',
    this.role = V2BerandaRole.petani,
    this.onLowStock,
    this.onOpenNotifications,
  }) : state = V2BerandaState.weatherUnavailable,
       siapPindahSubtitle = '2 semaian, HSS 15',
       lowStock = '3',
       filledHoles = '184';

  final String userName;
  final V2BerandaRole role;
  final V2BerandaState state;
  final String siapPindahSubtitle;
  final String lowStock;
  final String filledHoles;
  final VoidCallback? onLowStock;
  final VoidCallback? onOpenNotifications;

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

  @override
  void didUpdateWidget(V2BerandaPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) _state = widget.state;
  }

  bool get _petani => widget.role == V2BerandaRole.petani;

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _onTabTap(int index) {
    if (index == 0) return;
    _notice('Tab ${index + 1} alur v2 belum tersedia di halaman ini.');
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
    return Theme(
      data: V2Theme.light,
      child: Scaffold(
        backgroundColor: V2Colors.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    V2Space.xl,
                    V2Space.lg,
                    V2Space.xl,
                    V2Space.lg,
                  ),
                  child: _content(),
                ),
              ),
              V2TabBar(items: tabs, activeIndex: 0, onTap: _onTabTap),
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
              title: 'Berawan, 29°C',
              subtitle: 'Hujan 14.00',
              onTap: () => _notice('Halaman cuaca BMKG (10) belum tersedia.'),
            ),
        ],
      ],
    );
  }
}
