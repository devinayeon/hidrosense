import 'package:flutter/material.dart';

import '../components/v2_akun_action_bar.dart';
import '../components/v2_inventaris_assets.dart';
import '../components/v2_inventaris_data.dart';
import '../components/v2_inventaris_row.dart';
import '../components/v2_inventaris_skeleton.dart';
import '../theme/v2_tokens.dart';
import '../v2_roles.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_bottom_sheet.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_chip.dart';
import '../widgets/v2_error_state.dart';
import '../widgets/v2_group_list.dart';
import '../widgets/v2_option_row.dart';
import '../widgets/v2_select_field.dart';
import '../widgets/v2_tab_bar.dart';

/// Keadaan daftar stok yang punya frame sendiri di page 04.
enum V2InventarisState {
  /// Frame 4.1/4.2/4.7/4.8/4.9: daftar siap dibaca.
  ready,

  /// Frame 4.3: rangka kartu sebelum daftar tampil.
  loading,

  /// Frame 4.4: muat daftar gagal.
  error,
}

/// Isi tab "Stok" (frame 4.1–4.9) tanpa TabBar.
///
/// Dipasang oleh `V2BerandaPage` sebagai isi tab "Stok" supaya TabBar tetap
/// milik beranda. Untuk review desain, `V2InventarisListPage` membungkus view
/// ini bersama `V2TabBar` lengkap dengan bingkainya.
///
/// Urutan siap: judul "Stok", kolom cari, saringan jenis/keadaan, `Grup daftar`,
/// lalu footer "Tambah barang". Keadaan memuat dan gagal tidak menampilkan
/// saringan maupun footer (frame 4.3/4.4); keadaan kosong dan tanpa hasil tetap
/// menampilkan footer (frame 4.5/4.6).
class V2InventarisTabView extends StatefulWidget {
  const V2InventarisTabView({
    super.key,
    this.items,
    this.state = V2InventarisState.ready,
    this.initialQuery = '',
    this.initialJenis,
    this.initialStatusIndex = 0,
    this.openFilterOnStart = false,
    this.onAdd,
    this.onTapItem,
  });

  /// Barang yang ditampilkan; null berarti data contoh galeri.
  final List<V2InventarisItem>? items;
  final V2InventarisState state;

  /// Isi kolom cari saat halaman dibuka (frame 4.6 memakai "Zzz").
  final String initialQuery;

  /// Jenis terpilih saat halaman dibuka (frame 4.8/4.9 memakai Benih).
  final V2JenisBarang? initialJenis;

  /// Saringan keadaan terpilih: 0 Semua, 1 Menipis, 2 Arsip.
  final int initialStatusIndex;

  /// Membuka sheet "Jenis barang" begitu halaman tampil (frame 4.7).
  final bool openFilterOnStart;

  /// Tombol footer; null berarti hanya pratinjau (belum tersambung).
  final VoidCallback? onAdd;

  /// Ketukan baris; null berarti baris hanya dilihat.
  final ValueChanged<V2InventarisItem>? onTapItem;

  @override
  State<V2InventarisTabView> createState() => _V2InventarisTabViewState();
}

class _V2InventarisTabViewState extends State<V2InventarisTabView> {
  late final TextEditingController _search = TextEditingController(
    text: widget.initialQuery,
  );
  late V2JenisBarang? _jenis = widget.initialJenis;
  late int _status = widget.initialStatusIndex;

  bool get _loading => widget.state == V2InventarisState.loading;
  bool get _error => widget.state == V2InventarisState.error;

  /// Daftar sumber; keadaan kosong diberikan lewat `items` berisi list kosong.
  List<V2InventarisItem> get _source => widget.items ?? designInventaris;
  bool get _showFooter => !_loading && !_error;
  bool get _hasNoResults =>
      !_loading && !_error && _source.isNotEmpty && _filtered.isEmpty;

  /// Saringan aktif: arsip terpisah, lalu keadaan, jenis, dan teks pencarian.
  List<V2InventarisItem> get _filtered {
    final query = _search.text.trim().toLowerCase();
    return _source.where((item) {
      if (item.arsip != (_status == 2)) return false;
      if (_status == 1 && item.status == V2InventarisStatus.aman) return false;
      if (_jenis != null && item.jenis != _jenis) return false;
      if (query.isNotEmpty && !item.nama.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearchChanged);
    if (widget.openFilterOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openJenisSheet();
      });
    }
  }

  @override
  void dispose() {
    _search.removeListener(_onSearchChanged);
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  void _clearSearch() => _search.clear();

  /// Sheet "Jenis barang" (frame 4.7): pilihan ditahan di dalam sheet dan baru
  /// dipakai setelah "Terapkan", sehingga menutup sheet membatalkan perubahan.
  Future<void> _openJenisSheet() async {
    var draft = _jenis;
    final result = await showV2BottomSheet<(V2JenisBarang?,)>(
      context,
      child: StatefulBuilder(
        builder: (context, setSheet) => V2BottomSheet(
          title: 'Jenis barang',
          actions: V2Button(
            label: 'Terapkan',
            onPressed: () => Navigator.of(context).pop((draft,)),
          ),
          child: Column(
            children: [
              for (var index = 0; index < pilihanJenis.length; index++) ...[
                if (index > 0) const SizedBox(height: V2Space.lg),
                V2OptionRow(
                  label: pilihanJenis[index].$1,
                  state: draft == pilihanJenis[index].$2
                      ? V2OptionState.selected
                      : V2OptionState.normal,
                  onTap: () => setSheet(() => draft = pilihanJenis[index].$2),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _jenis = result.$1);
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
          _header(includeSearch: false),
          const SizedBox(height: V2Space.lg),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: V2Space.xl),
            child: V2InventarisSkeleton(),
          ),
        ],
      );
    }

    if (_error) {
      return _scroll(
        children: [
          _header(includeSearch: false),
          const SizedBox(height: V2Space.lg),
          const SizedBox(height: V2Space.xxxl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
            child: V2ErrorState(
              title: 'Gagal memuat',
              body: 'Periksa internet, lalu coba lagi.',
              actionLabel: 'Coba lagi',
              onAction: () {},
              illustration: Image.asset(
                V2InventarisAssets.offlineNoInternet,
                width: 160,
                height: 160,
              ),
            ),
          ),
        ],
      );
    }

    // Keadaan kosong dan tanpa hasil memakai judul, kolom cari, dan saringan
    // yang sama; yang berbeda hanya isi area daftar (frame 4.5/4.6).
    if (_source.isEmpty) {
      return _scroll(
        children: [
          _header(includeSearch: false),
          const SizedBox(height: V2Space.lg),
          const SizedBox(height: 80),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
            child: V2ErrorState(
              title: 'Belum ada stok',
              body: 'Catat benih, nutrisi, dan media.',
              illustration: Image.asset(
                V2InventarisAssets.inventoryStock,
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
        if (_hasNoResults) ...[
          const SizedBox(height: 48),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
            child: V2ErrorState(
              title: 'Tidak ketemu',
              body: 'Coba kata lain.',
              illustration: Image.asset(
                V2InventarisAssets.noSearchResults,
                width: 120,
                height: 120,
              ),
            ),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
            child: V2GroupList(
              children: [
                for (final item in _filtered)
                  V2InventarisRow(
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

  /// Judul "Stok" dengan kolom cari di bawahnya (langkah 16).
  Widget _header({bool includeSearch = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: V2Space.xl),
          child: V2ScreenHeader(title: 'Stok'),
        ),
        if (includeSearch) ...[
          const SizedBox(height: V2Space.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
            child: V2SearchField(
              hint: 'Cari barang',
              controller: _search,
              onChanged: (_) => setState(() {}),
              onClear: _clearSearch,
            ),
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
          V2Chip(
            label: labelChipJenis(_jenis),
            selected: _jenis != null,
            onTap: _openJenisSheet,
          ),
          for (var index = 0; index < labelChipStatus.length; index++) ...[
            const SizedBox(width: V2Space.sm),
            V2Chip(
              label: labelChipStatus[index],
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
      actions: [
        V2Button(label: 'Tambah barang', onPressed: widget.onAdd ?? () {}),
      ],
    );
  }
}

/// Halaman daftar stok lengkap dengan TabBar (frame 4.1–4.9).
///
/// Dipakai galeri review supaya setiap keadaan bisa dibuka langsung; di aplikasi
/// nyata isinya dipasang oleh `V2BerandaPage` lewat [V2InventarisTabView].
class V2InventarisListPage extends StatelessWidget {
  const V2InventarisListPage({
    super.key,
    this.items,
    this.role = V2BerandaRole.petani,
    this.state = V2InventarisState.ready,
    this.initialQuery = '',
    this.initialJenis,
    this.initialStatusIndex = 0,
    this.openFilterOnStart = false,
    this.onAdd,
    this.onTapItem,
  });

  /// Frame `4.1 Stok (Petani)`.
  const V2InventarisListPage.ready({Key? key}) : this(key: key);

  /// Frame `4.2 Stok (Pegawai)`.
  const V2InventarisListPage.pegawai({Key? key})
    : this(key: key, role: V2BerandaRole.pegawai);

  /// Frame `4.3 Memuat stok`.
  const V2InventarisListPage.loading({Key? key})
    : this(key: key, state: V2InventarisState.loading);

  /// Frame `4.4 Gagal memuat stok`.
  const V2InventarisListPage.error({Key? key})
    : this(key: key, state: V2InventarisState.error);

  /// Frame `4.5 Stok kosong`.
  const V2InventarisListPage.empty({Key? key})
    : this(key: key, items: const <V2InventarisItem>[]);

  /// Frame `4.6 Cari tanpa hasil`.
  const V2InventarisListPage.noResults({Key? key})
    : this(key: key, initialQuery: 'Zzz');

  /// Frame `4.7 Pilih jenis`.
  const V2InventarisListPage.filterSheet({Key? key})
    : this(key: key, openFilterOnStart: true);

  /// Frame `4.8 Stok, jenis Benih`.
  const V2InventarisListPage.jenisBenih({Key? key})
    : this(key: key, initialJenis: V2JenisBarang.benih);

  /// Frame `4.9 Stok menipis, jenis Benih`.
  const V2InventarisListPage.menipisBenih({Key? key})
    : this(
        key: key,
        initialJenis: V2JenisBarang.benih,
        initialStatusIndex: 1,
      );

  final List<V2InventarisItem>? items;
  final V2BerandaRole role;
  final V2InventarisState state;
  final String initialQuery;
  final V2JenisBarang? initialJenis;
  final int initialStatusIndex;
  final bool openFilterOnStart;
  final VoidCallback? onAdd;
  final ValueChanged<V2InventarisItem>? onTapItem;

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const V2InventarisListPage());

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
                child: V2InventarisTabView(
                  items: items,
                  state: state,
                  initialQuery: initialQuery,
                  initialJenis: initialJenis,
                  initialStatusIndex: initialStatusIndex,
                  openFilterOnStart: openFilterOnStart,
                  onAdd: onAdd,
                  onTapItem: onTapItem,
                ),
              ),
              V2TabBar(
                items: v2TabsFor(role),
                activeIndex: v2StokTabIndex,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
