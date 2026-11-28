import 'package:flutter/material.dart';

import '../components/v2_group_label.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_icon.dart';
import '../widgets/v2_list_item.dart';
import '../widgets/v2_refresh_button.dart';

/// Tujuan yang dibuka saat sebuah notifikasi ditekan.
///
/// Halaman notifikasi hanya mengembalikan pilihan ini lewat `Navigator.pop`;
/// pemanggil (Beranda) yang tahu cara berpindah tab, supaya notifikasi tidak
/// memaksa tahu susunan tab (BUG-30).
enum V2NotificationTarget { none, semaian, stok }

/// Kunci penanda "belum dibaca" (dipakai pengujian widget dan pembaca layar).
const Key v2NotifUnreadDotKey = Key('notifikasi-belum-dibaca');

/// Satu notifikasi di halaman 2.4.
class V2Notification {
  const V2Notification({
    required this.id,
    required this.title,
    required this.subtitle,
    this.icon = V2IconName.sprout,
    this.read = false,
    this.target = V2NotificationTarget.none,
  });

  /// Identitas stabil antar pemuatan (mis. `semaian-12`). Dipakai menyimpan
  /// status "sudah dibaca" per pengguna (D-23).
  final String id;

  final String title;
  final String subtitle;
  final V2IconName icon;

  /// True kalau pengguna sudah membuka notifikasi ini.
  final bool read;

  /// Halaman yang dibuka saat notifikasi ditekan.
  final V2NotificationTarget target;
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
///
/// Setiap baris bisa ditekan: baris ditandai sudah dibaca ([onMarkRead]) lalu
/// halaman mengembalikan [V2Notification.target] ke pemanggil supaya tujuan
/// yang relevan dibuka (BUG-30, D-23). Baris yang belum dibaca diberi penanda
/// titik — beda bentuk, bukan hanya beda warna.
class V2NotificationsPage extends StatefulWidget {
  const V2NotificationsPage({
    super.key,
    this.groups,
    this.onMarkRead,
    this.onMarkAllRead,
    this.onRefresh,
  });

  final List<V2NotificationGroup>? groups;

  /// Dipanggil saat satu baris dibuka; menyimpan "sudah dibaca" ke penyimpanan.
  final ValueChanged<String>? onMarkRead;

  /// Dipanggil saat "Tandai semua dibaca" ditekan, berisi id yang belum dibaca.
  final ValueChanged<List<String>>? onMarkAllRead;

  /// Mengambil grup notifikasi terbaru dari backend; null berarti galeri tanpa
  /// tarik-turun/tombol muat ulang.
  final Future<List<V2NotificationGroup>> Function()? onRefresh;

  static const List<V2NotificationGroup> designGroups = [
    V2NotificationGroup(
      label: 'Baru',
      items: [
        V2Notification(
          id: 'design-semaian-1',
          title: 'Semaian HSS 15',
          subtitle: 'Siap pindah ke meja, 08.00',
          target: V2NotificationTarget.semaian,
        ),
        V2Notification(
          id: 'design-stok-1',
          title: 'Stok menipis',
          subtitle: 'Butterhead sisa 2 pak, 07.30',
          icon: V2IconName.box,
          target: V2NotificationTarget.stok,
        ),
      ],
    ),
    V2NotificationGroup(
      label: 'Sebelumnya',
      items: [
        V2Notification(
          id: 'design-hujan-1',
          title: 'Hujan sore',
          subtitle: 'Tunda semprot, 15.00',
          icon: V2IconName.cloud,
          read: true,
        ),
        V2Notification(
          id: 'design-semaian-2',
          title: 'Semaian HSS 15',
          subtitle: '12 Nov, 08.00',
          read: true,
          target: V2NotificationTarget.semaian,
        ),
      ],
    ),
  ];

  static Route<V2NotificationTarget> route({
    List<V2NotificationGroup>? groups,
    ValueChanged<String>? onMarkRead,
    ValueChanged<List<String>>? onMarkAllRead,
    Future<List<V2NotificationGroup>> Function()? onRefresh,
  }) {
    return MaterialPageRoute<V2NotificationTarget>(
      builder: (_) => V2NotificationsPage(
        groups: groups,
        onMarkRead: onMarkRead,
        onMarkAllRead: onMarkAllRead,
        onRefresh: onRefresh,
      ),
    );
  }

  @override
  State<V2NotificationsPage> createState() => _V2NotificationsPageState();
}

class _V2NotificationsPageState extends State<V2NotificationsPage> {
  late List<V2NotificationGroup> _groups =
      widget.groups ?? V2NotificationsPage.designGroups;

  /// Id yang sudah dibaca selama halaman ini terbuka; diisi dari status awal.
  late final Set<String> _read = {
    for (final group in _groups)
      for (final item in group.items)
        if (item.read) item.id,
  };

  List<String> get _unreadIds => [
    for (final group in _groups)
      for (final item in group.items)
        if (!_read.contains(item.id)) item.id,
  ];

  bool get _hasUnread => _unreadIds.isNotEmpty;

  /// Ketukan baris: tandai dibaca, lalu tutup halaman dengan tujuan baris itu
  /// sehingga Beranda bisa membuka tab yang relevan (BUG-30).
  void _open(V2Notification item) {
    if (!_read.contains(item.id)) {
      setState(() => _read.add(item.id));
      widget.onMarkRead?.call(item.id);
    }
    if (item.target != V2NotificationTarget.none) {
      Navigator.of(context).pop(item.target);
    }
  }

  void _markAll() {
    final ids = _unreadIds;
    if (ids.isEmpty) return;
    setState(() => _read.addAll(ids));
    widget.onMarkAllRead?.call(ids);
  }

  /// Tarik-turun/tombol: ambil grup terbaru, buang tanda "sudah dibaca" yang
  /// id-nya tidak ada lagi di daftar baru.
  Future<void> _refresh() async {
    final refresh = widget.onRefresh;
    if (refresh == null) return;
    final groups = await refresh();
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _read.retainWhere(
        (id) => groups.any((g) => g.items.any((item) => item.id == id)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
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
                trailing: V2RefreshButton(
                  onRefresh: widget.onRefresh == null ? null : _refresh,
                ),
              ),
              Expanded(
                child: _refreshable(
                  SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      V2Space.xl,
                      V2Space.sm,
                      V2Space.xl,
                      V2Space.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final group in _groups) ...[
                          V2GroupLabel(group.label),
                          for (final item in group.items) ...[
                            const SizedBox(height: V2Space.sm),
                            V2ListItem(
                              title: item.title,
                              subtitle: item.subtitle,
                              icon: item.icon,
                              trailing: _read.contains(item.id)
                                  ? null
                                  : const _UnreadDot(key: v2NotifUnreadDotKey),
                              onTap: () => _open(item),
                            ),
                          ],
                          const SizedBox(height: V2Space.sm),
                        ],
                      ],
                    ),
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
                    // Nonaktif saat tidak ada yang belum dibaca (D-23).
                    onPressed: _hasUnread ? _markAll : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tarik-turun hanya aktif bila ada sumber data nyata.
  Widget _refreshable(Widget child) {
    if (widget.onRefresh == null) return child;
    return RefreshIndicator(onRefresh: _refresh, child: child);
  }
}

/// Penanda "belum dibaca": titik bentuk, bukan sekadar beda warna.
class _UnreadDot extends StatelessWidget {
  const _UnreadDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Belum dibaca',
      child: const SizedBox(
        width: 10,
        height: 10,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: V2Colors.blue500,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
