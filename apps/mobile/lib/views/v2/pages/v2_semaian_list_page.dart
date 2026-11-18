import 'dart:async';

import 'package:flutter/material.dart';

import '../components/v2_akun_action_bar.dart';
import '../components/v2_semaian_assets.dart';
import '../components/v2_semaian_data.dart';
import '../components/v2_semaian_row.dart';
import '../components/v2_semaian_skeleton.dart';
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
import 'v2_semaian_detail_page.dart';
import 'v2_semaian_form_page.dart';

/// Keadaan daftar semaian yang punya frame sendiri di page 05.
enum V2SemaianState {
  /// Frame 5.1/5.2/5.6: daftar siap dibaca.
  ready,

  /// Frame 5.3: rangka kartu sebelum daftar tampil.
  loading,

  /// Frame 5.4: muat daftar gagal.
  error,
}

/// Tiga arah di dalam tab "Tanam" (frame 5.1); Semaian yang sedang dipilih.
const List<String> v2SemaianSegmen = <String>['Semaian', 'Meja', 'Panen'];

/// Isi tab "Tanam" (frame 5.1–5.6) tanpa TabBar.
///
/// Dipasang oleh `V2BerandaPage` sebagai isi tab "Tanam" supaya TabBar tetap
/// milik beranda. Untuk review desain, `V2SemaianListPage` membungkus view ini
/// bersama `V2TabBar` lengkap dengan bingkainya.
///
/// Urutan siap: judul "Tanam", segmen Semaian/Meja/Panen, saringan keadaan,
/// lalu `Grup daftar`. Keadaan memuat dan gagal tidak menampilkan saringan
/// maupun footer (frame 5.3/5.4); keadaan kosong tetap menampilkan footer
/// (frame 5.5), sedangkan chip "Selesai" menyembunyikannya (frame 5.6).
class V2SemaianTabView extends StatefulWidget {
  const V2SemaianTabView({
    super.key,
    this.items,
    this.state = V2SemaianState.ready,
    this.initialStatusIndex = 0,
    this.toast,
    this.toastTone = V2ToastTone.success,
    this.offline = false,
    this.onSegmentChanged,
    this.onAdd,
    this.onTapItem,
  });

  /// Semaian yang ditampilkan; null berarti data contoh galeri.
  final List<V2SemaianItem>? items;
  final V2SemaianState state;

  /// Saringan keadaan terpilih: 0 Semua, 1 Siap pindah, 2 Selesai.
  final int initialStatusIndex;

  /// Toast yang melayang di atas tombol footer.
  final String? toast;
  final V2ToastTone toastTone;

  /// Menampilkan banner offline di bawah segmen (frame 5.13).
  final bool offline;

  /// Perpindahan segmen Semaian/Meja/Panen; null berarti hanya dilihat.
  final ValueChanged<int>? onSegmentChanged;

  /// Tombol footer; null berarti hanya pratinjau (belum tersambung).
  final VoidCallback? onAdd;

  /// Ketukan baris; null berarti baris hanya dilihat.
  final ValueChanged<V2SemaianItem>? onTapItem;

  @override
  State<V2SemaianTabView> createState() => _V2SemaianTabViewState();
}

class _V2SemaianTabViewState extends State<V2SemaianTabView> {
  late int _status = widget.initialStatusIndex;

  bool get _loading => widget.state == V2SemaianState.loading;
  bool get _error => widget.state == V2SemaianState.error;

  /// Daftar sumber; keadaan kosong diberikan lewat `items` berisi list kosong.
  List<V2SemaianItem> get _source => widget.items ?? designSemaian;

  // Chip "Selesai" tidak menawarkan "Tambah semaian" (frame 5.6).
  bool get _showFooter => !_loading && !_error && _status != 2;

  /// Saringan aktif: Semua menyembunyikan baris selesai, "Siap pindah" hanya
  /// baris yang sudah HSS 15, "Selesai" hanya baris selesai.
  List<V2SemaianItem> get _filtered => _source.where((item) {
    if (_status == 2) return item.selesai;
    if (item.selesai) return false;
    if (_status == 1) return item.siapPindah;
    return true;
  }).toList();

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
            child: V2SemaianSkeleton(),
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
              title: 'Belum ada semaian',
              body: 'Catat semaian pertama.',
              illustration: Image.asset(
                V2SemaianAssets.nurserySeedlings,
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
          // Semaian selesai berdiri sebagai kartu `#E5E8EC` sendiri-sendiri
          // (frame 5.6), sedangkan semaian berjalan duduk di dalam satu
          // `Grup daftar` putih (frame 5.1).
          child: _status == 2
              ? Column(
                  children: [
                    for (
                      var index = 0;
                      index < _filtered.length;
                      index++
                    ) ...[
                      if (index > 0) const SizedBox(height: V2Space.sm),
                      V2SemaianRow(
                        item: _filtered[index],
                        onTap: widget.onTapItem == null
                            ? null
                            : () => widget.onTapItem!(_filtered[index]),
                      ),
                    ],
                  ],
                )
              : V2GroupList(
                  children: [
                    for (final item in _filtered)
                      V2SemaianRow(
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

  /// Judul "Tanam" dengan segmen Semaian/Meja/Panen di bawahnya (frame 5.1).
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
            labels: v2SemaianSegmen,
            selectedIndex: 0,
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
          for (var index = 0; index < labelChipSemaian.length; index++) ...[
            if (index > 0) const SizedBox(width: V2Space.sm),
            V2Chip(
              label: labelChipSemaian[index],
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
        V2Button(label: 'Tambah semaian', onPressed: widget.onAdd ?? () {}),
      ],
    );
  }
}

/// Halaman daftar semaian lengkap dengan TabBar (frame 5.1–5.6).
///
/// Dipakai galeri review supaya setiap keadaan bisa dibuka langsung; di aplikasi
/// nyata isinya dipasang oleh `V2BerandaPage` lewat [V2SemaianTabView].
class V2SemaianListPage extends StatefulWidget {
  const V2SemaianListPage({
    super.key,
    this.items,
    this.role = V2BerandaRole.petani,
    this.state = V2SemaianState.ready,
    this.initialStatusIndex = 0,
    this.toast,
    this.toastTone = V2ToastTone.success,
    this.offline = false,
    this.onAdd,
    this.onTapItem,
  });

  /// Frame `5.1 Semaian (Petani)`.
  const V2SemaianListPage.ready({Key? key}) : this(key: key);

  /// Frame `5.2 Semaian (Pegawai)`.
  const V2SemaianListPage.pegawai({Key? key})
    : this(key: key, role: V2BerandaRole.pegawai);

  /// Frame `5.3 Memuat semaian`.
  const V2SemaianListPage.loading({Key? key})
    : this(key: key, state: V2SemaianState.loading);

  /// Frame `5.4 Gagal memuat semaian`.
  const V2SemaianListPage.error({Key? key})
    : this(key: key, state: V2SemaianState.error);

  /// Frame `5.5 Semaian kosong`.
  const V2SemaianListPage.empty({Key? key})
    : this(key: key, items: const <V2SemaianItem>[]);

  /// Frame `5.6 Semaian selesai`.
  const V2SemaianListPage.selesai({Key? key})
    : this(key: key, initialStatusIndex: 2);

  /// Frame `5.12 Semaian ditambahkan`: semaian baru di paling atas dan toast.
  V2SemaianListPage.ditambahkan({Key? key})
    : this(
        key: key,
        items: designSemaianDitambah,
        toast: 'Semaian ditambahkan',
      );

  /// Frame `5.13 Semaian menunggu sinkron`: banner offline, baris "Antrean",
  /// dan toast info.
  V2SemaianListPage.offline({Key? key})
    : this(
        key: key,
        items: designSemaianAntrean,
        toast: 'Tersimpan di HP',
        toastTone: V2ToastTone.info,
        offline: true,
      );

  final List<V2SemaianItem>? items;
  final V2BerandaRole role;
  final V2SemaianState state;
  final int initialStatusIndex;

  /// Toast yang sudah tampil saat halaman dibuka.
  final String? toast;
  final V2ToastTone toastTone;

  /// Menampilkan banner offline di bawah segmen (frame 5.13).
  final bool offline;

  final VoidCallback? onAdd;
  final ValueChanged<V2SemaianItem>? onTapItem;

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const V2SemaianListPage());

  @override
  State<V2SemaianListPage> createState() => _V2SemaianListPageState();
}

class _V2SemaianListPageState extends State<V2SemaianListPage> {
  late List<V2SemaianItem> _items = widget.items ?? designSemaian;
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
    _tambahSemaian();
  }

  /// Buka form 5.7 lalu sisipkan semaian baru di paling atas (frame 5.12);
  /// saat offline barisnya menunggu sinkron dan toast-nya info (frame 5.13).
  Future<void> _tambahSemaian() async {
    final item = await Navigator.of(
      context,
    ).push<V2SemaianItem>(V2SemaianFormPage.route());
    if (!mounted || item == null) return;
    setState(() {
      _items = [
        widget.offline ? item.copyWith(antrean: true) : item,
        ..._items,
      ];
      _toast = widget.offline ? 'Tersimpan di HP' : 'Semaian ditambahkan';
      _toastTone = widget.offline ? V2ToastTone.info : V2ToastTone.success;
    });
    _scheduleToastDismiss();
  }

  void _openDetail(V2SemaianItem item) {
    if (widget.onTapItem != null) {
      widget.onTapItem!(item);
      return;
    }
    _bukaDetail(item);
  }

  /// Buka detail 5.15; hasil ubah/pindah menggantikan baris lama.
  Future<void> _bukaDetail(V2SemaianItem item) async {
    final updated = await Navigator.of(
      context,
    ).push<V2SemaianItem>(V2SemaianDetailPage.route(item));
    if (!mounted || updated == null) return;
    setState(() {
      _items = [
        for (final baris in _items)
          if (baris.id == updated.id) updated else baris,
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
                child: V2SemaianTabView(
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
