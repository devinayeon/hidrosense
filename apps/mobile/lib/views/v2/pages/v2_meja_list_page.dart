import 'dart:async';

import 'package:flutter/material.dart';

import '../components/v2_akun_action_bar.dart';
import '../components/v2_meja_data.dart';
import '../components/v2_meja_row.dart';
import '../components/v2_meja_skeleton.dart';
import '../components/v2_semaian_assets.dart';
import '../theme/v2_tokens.dart';
import '../v2_roles.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_banner.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_chip.dart';
import '../widgets/v2_error_state.dart';
import '../widgets/v2_group_list.dart';
import '../widgets/v2_segmented.dart';
import '../widgets/v2_tab_bar.dart';
import 'v2_meja_detail_page.dart';
import 'v2_meja_form_page.dart';

/// Keadaan daftar meja yang punya frame sendiri di page 06.
enum V2MejaState {
  /// Frame 6.1/6.2/6.8/6.9: daftar siap dibaca.
  ready,

  /// Frame 6.3: rangka kartu sebelum daftar tampil.
  loading,

  /// Frame 6.4: muat daftar gagal.
  error,
}

const List<String> v2TanamSegmen = <String>['Semaian', 'Meja', 'Panen'];

/// Isi tab "Tanam" segmen Meja (frame 6.1–6.5) tanpa TabBar.
///
/// Dipasang sebagai isi tab "Tanam" di beranda supaya TabBar tetap milik
/// beranda. Untuk review desain, `V2MejaListPage` membungkus view ini bersama
/// `V2TabBar` lengkap dengan bingkainya.
///
/// Urutan siap: judul "Tanam", segmen Semaian/Meja/Panen, saringan keadaan,
/// lalu `Grup daftar`. Keadaan memuat dan gagal tidak menampilkan saringan
/// maupun footer (frame 6.3/6.4); keadaan kosong tetap menampilkan footer
/// "Tambah meja" (frame 6.5).
class V2MejaTabView extends StatefulWidget {
  const V2MejaTabView({
    super.key,
    this.items,
    this.state = V2MejaState.ready,
    this.initialStatusIndex = 0,
    this.toast,
    this.toastTone = V2ToastTone.success,
    this.offline = false,
    this.onSegmentChanged,
    this.onAdd,
    this.onTapItem,
  });

  /// Meja yang ditampilkan; null berarti data contoh galeri.
  final List<V2MejaItem>? items;
  final V2MejaState state;

  /// Saringan keadaan terpilih: 0 Semua, 1 Tersedia, 2 Penuh, 3 Perawatan.
  final int initialStatusIndex;

  /// Toast yang melayang di atas tombol footer.
  final String? toast;
  final V2ToastTone toastTone;

  /// Menampilkan banner offline di bawah segmen (frame 6.9).
  final bool offline;

  /// Perpindahan segmen Semaian/Meja/Panen; null berarti hanya dilihat.
  final ValueChanged<int>? onSegmentChanged;

  /// Tombol footer; null berarti hanya pratinjau (belum tersambung).
  final VoidCallback? onAdd;

  /// Ketukan baris; null berarti baris hanya dilihat.
  final ValueChanged<V2MejaItem>? onTapItem;

  @override
  State<V2MejaTabView> createState() => _V2MejaTabViewState();
}

class _V2MejaTabViewState extends State<V2MejaTabView> {
  late int _status = widget.initialStatusIndex;

  bool get _loading => widget.state == V2MejaState.loading;
  bool get _error => widget.state == V2MejaState.error;

  /// Daftar sumber; keadaan kosong diberikan lewat `items` berisi list kosong.
  List<V2MejaItem> get _source => widget.items ?? designDaftarMeja;

  bool get _showFooter => !_loading && !_error;

  /// Saringan aktif: Semua menampilkan semua meja, chip lain hanya keadaan
  /// yang dipilih (frame 6.1).
  List<V2MejaItem> get _filtered {
    if (_status == 0) return _source;
    final status = switch (_status) {
      1 => V2MejaStatus.tersedia,
      2 => V2MejaStatus.penuh,
      _ => V2MejaStatus.perawatan,
    };
    return _source.where((item) => item.status == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _buildContent()),
        if (_showFooter) _buildFooter(),
      ],
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return _scroll(
        children: [
          _header(),
          const SizedBox(height: V2Space.lg),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: V2Space.xl),
            child: V2MejaSkeleton(),
          ),
        ],
      );
    }

    if (_error) {
      return _scroll(
        children: [
          _header(),
          const SizedBox(height: V2Space.lg),
          const SizedBox(height: V2Space.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
            child: V2ErrorState(
              title: 'Gagal memuat',
              body: 'Periksa internet, lalu coba lagi.',
              actionLabel: 'Coba lagi',
              onAction: () {},
              illustration: Image.asset(
                V2SemaianAssets.offlineNoInternet,
                width: 160,
                height: 160,
              ),
            ),
          ),
        ],
      );
    }

    if (_source.isEmpty) {
      return _scroll(
        children: [
          _header(),
          const SizedBox(height: V2Space.lg),
          const SizedBox(height: 64),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
            child: V2ErrorState(
              title: 'Belum ada meja',
              body: 'Catat meja tanam pertama.',
              illustration: Image.asset(
                V2SemaianAssets.growingTable,
                width: 160,
                height: 160,
              ),
            ),
          ),
        ],
      );
    }

    return _scroll(
      children: [
        _header(),
        const SizedBox(height: V2Space.lg),
        _chips(),
        const SizedBox(height: V2Space.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
          child: V2GroupList(
            children: [
              for (final item in _filtered)
                V2MejaRow(
                  item: item,
                  onTap: widget.onTapItem == null
                      ? null
                      : () => widget.onTapItem!(item),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _scroll({required List<Widget> children}) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.only(top: V2Space.lg, bottom: V2Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  /// Judul "Tanam" dengan segmen Semaian/Meja/Panen di bawahnya (frame 6.1).
  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: V2Space.xl),
          child: V2ScreenHeader(title: 'Tanam'),
        ),
        const SizedBox(height: V2Space.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
          child: V2Segmented(
            labels: v2TanamSegmen,
            selectedIndex: 1,
            onChanged: widget.onSegmentChanged,
          ),
        ),
        if (widget.offline) ...[
          const SizedBox(height: V2Space.lg),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: V2Space.xl),
            child: V2Banner(message: 'Offline. Data tersimpan di HP.'),
          ),
        ],
      ],
    );
  }

  Widget _chips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
      child: Row(
        children: [
          for (var index = 0; index < labelChipMeja.length; index++) ...[
            if (index > 0) const SizedBox(width: V2Space.sm),
            V2Chip(
              label: labelChipMeja[index],
              selected: _status == index,
              onTap: () => setState(() => _status = index),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return V2AkunActionBar(
      toast: widget.toast,
      toastTone: widget.toastTone,
      actions: [
        V2Button(label: 'Tambah meja', onPressed: widget.onAdd ?? () {}),
      ],
    );
  }
}

/// Halaman daftar meja lengkap dengan TabBar (frame 6.1–6.5).
///
/// Dipakai galeri review supaya setiap keadaan bisa dibuka langsung; di aplikasi
/// nyata isinya dipasang oleh `V2BerandaPage` lewat [V2MejaTabView].
class V2MejaListPage extends StatefulWidget {
  const V2MejaListPage({
    super.key,
    this.items,
    this.role = V2BerandaRole.petani,
    this.state = V2MejaState.ready,
    this.initialStatusIndex = 0,
    this.toast,
    this.toastTone = V2ToastTone.success,
    this.offline = false,
    this.onAdd,
    this.onTapItem,
  });

  /// Frame `6.1 Meja tanam (Petani)`.
  const V2MejaListPage.petani({Key? key}) : this(key: key);

  /// Frame `6.2 Meja tanam (Pegawai)`.
  const V2MejaListPage.pegawai({Key? key})
    : this(key: key, role: V2BerandaRole.pegawai);

  /// Frame `6.3 Memuat meja`.
  const V2MejaListPage.memuat({Key? key})
    : this(key: key, state: V2MejaState.loading);

  /// Frame `6.4 Gagal memuat meja`.
  const V2MejaListPage.gagal({Key? key})
    : this(key: key, state: V2MejaState.error);

  /// Frame `6.5 Meja kosong`.
  const V2MejaListPage.kosong({Key? key})
    : this(key: key, items: const <V2MejaItem>[]);

  /// Frame `6.8 Meja ditambahkan`: Meja C1 di paling atas dan toast.
  V2MejaListPage.ditambahkan({Key? key})
    : this(
        key: key,
        items: designDaftarMejaBaru,
        toast: 'Meja ditambahkan',
      );

  /// Frame `6.9 Tersimpan di HP`: banner offline, baris "Antrean", dan toast
  /// info.
  V2MejaListPage.offline({Key? key})
    : this(
        key: key,
        items: designDaftarMejaOffline,
        toast: 'Tersimpan di HP',
        toastTone: V2ToastTone.info,
        offline: true,
      );

  final List<V2MejaItem>? items;
  final V2BerandaRole role;
  final V2MejaState state;
  final int initialStatusIndex;

  /// Toast yang sudah tampil saat halaman dibuka.
  final String? toast;
  final V2ToastTone toastTone;

  /// Menampilkan banner offline di bawah segmen (frame 6.9).
  final bool offline;

  final VoidCallback? onAdd;
  final ValueChanged<V2MejaItem>? onTapItem;

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const V2MejaListPage());

  @override
  State<V2MejaListPage> createState() => _V2MejaListPageState();
}

class _V2MejaListPageState extends State<V2MejaListPage> {
  late List<V2MejaItem> _items = widget.items ?? designDaftarMeja;
  late String? _toast = widget.toast;
  late V2ToastTone _toastTone = widget.toastTone;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    if (_toast != null) _scheduleToastDismiss();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  void _scheduleToastDismiss() {
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  void _openAdd() {
    if (widget.onAdd != null) {
      widget.onAdd!();
      return;
    }
    _tambahMeja();
  }

  /// Buka form 6.6 lalu sisipkan meja baru di paling atas (frame 6.8); saat
  /// offline barisnya menunggu sinkron dan toast-nya info (frame 6.9).
  Future<void> _tambahMeja() async {
    final item = await Navigator.of(
      context,
    ).push<V2MejaItem>(V2MejaFormPage.route());
    if (!mounted || item == null) return;
    setState(() {
      _items = [
        widget.offline ? item.copyWith(antrean: true) : item,
        ..._items,
      ];
      _toast = widget.offline ? 'Tersimpan di HP' : 'Meja ditambahkan';
      _toastTone = widget.offline ? V2ToastTone.info : V2ToastTone.success;
    });
    _scheduleToastDismiss();
  }

  void _openDetail(V2MejaItem item) {
    if (widget.onTapItem != null) {
      widget.onTapItem!(item);
      return;
    }
    _bukaDetail(item);
  }

  /// Buka detail 6.10; hasil ubah meja/status menggantikan baris lama.
  Future<void> _bukaDetail(V2MejaItem item) async {
    final updated = await Navigator.of(
      context,
    ).push<V2MejaItem>(V2MejaDetailPage.route(item));
    if (!mounted || updated == null) return;
    setState(() {
      _items = [
        for (final baris in _items)
          if (baris.kode == updated.kode) updated else baris,
      ];
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
              Expanded(
                child: V2MejaTabView(
                  items: _items,
                  state: widget.state,
                  initialStatusIndex: widget.initialStatusIndex,
                  toast: _toast,
                  toastTone: _toastTone,
                  offline: widget.offline,
                  onAdd: _openAdd,
                  onTapItem: _openDetail,
                ),
              ),
              V2TabBar(
                items: v2TabsFor(widget.role),
                activeIndex: v2TanamTabIndex,
              ),
            ],
          ),
        ),
      ),
    );
  }
}