import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_badge.dart';
import '../widgets/v2_banner.dart';
import '../widgets/v2_bento_tile.dart';
import '../widgets/v2_bottom_sheet.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_card.dart';
import '../widgets/v2_checklist.dart';
import '../widgets/v2_chip.dart';
import '../widgets/v2_cycle_card.dart';
import '../widgets/v2_date_sheet.dart';
import '../widgets/v2_dialog.dart';
import '../widgets/v2_error_state.dart';
import '../widgets/v2_hole_grid.dart';
import '../widgets/v2_icon.dart';
import '../widgets/v2_icon_button.dart';
import '../widgets/v2_list_item.dart';
import '../widgets/v2_option_row.dart';
import '../widgets/v2_pagination.dart';
import '../widgets/v2_pick_sheet.dart';
import '../widgets/v2_segmented.dart';
import '../widgets/v2_select_field.dart';
import '../widgets/v2_skeleton.dart';
import '../widgets/v2_status_bar.dart';
import '../widgets/v2_stepper.dart';
import '../widgets/v2_stock_item.dart';
import '../widgets/v2_summary_card.dart';
import '../widgets/v2_tab_bar.dart';
import '../widgets/v2_text_field.dart';
import '../widgets/v2_timeline_step.dart';
import 'v2_gallery_section.dart';

/// Deretan semua widget reusable v2 untuk direview di perangkat.
class V2FoundationGallery extends StatefulWidget {
  const V2FoundationGallery({super.key});

  @override
  State<V2FoundationGallery> createState() => _V2FoundationGalleryState();
}

class _V2FoundationGalleryState extends State<V2FoundationGallery> {
  final TextEditingController _filledController = TextEditingController(
    text: 'benih.romaine',
  );
  final TextEditingController _searchController = TextEditingController();

  int _segmented = 1;
  int _segmented3 = 0;
  int _option = 0;
  int _qty = 2;
  final int _page = 1;
  int _tab = 2;
  int _stockMode = 0;
  int _stockQty = 2;
  int _day = 16;
  int? _picked = 0;
  final Set<String> _filters = <String>{'Semua'};

  @override
  void dispose() {
    _filledController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget _pair(Widget first, Widget second) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - V2Space.md) / 2;
        return Wrap(
          spacing: V2Space.md,
          runSpacing: V2Space.md,
          children: [
            SizedBox(width: width, child: first),
            SizedBox(width: width, child: second),
          ],
        );
      },
    );
  }

  Future<void> _openPickSheet() async {
    var selected = _picked ?? 0;
    await showV2BottomSheet<void>(
      context,
      child: StatefulBuilder(
        builder: (context, setSheetState) => V2PickSheet(
          title: 'Jenis barang',
          options: const ['Benih', 'Nutrisi', 'Media', 'Obat'],
          selectedIndex: selected,
          onSelect: (index) => setSheetState(() => selected = index),
          confirmLabel: 'Pilih',
          onConfirm: () {
            setState(() => _picked = selected);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  Future<void> _openStockSheet() async {
    var mode = _stockMode;
    var qty = _stockQty;
    await showV2BottomSheet<void>(
      context,
      child: StatefulBuilder(
        builder: (context, setSheetState) => V2StockSheet(
          modeIndex: mode,
          onModeChanged: (index) => setSheetState(() => mode = index),
          value: qty,
          onMinus: () => setSheetState(() => qty = (qty - 1).clamp(0, 99)),
          onPlus: () => setSheetState(() => qty += 1),
          preview: mode == 0
              ? 'Tambah $qty pak. Stok jadi 14 pak.'
              : 'Pakai $qty pak. Stok jadi 10 pak.',
          onConfirm: () {
            setState(() {
              _stockMode = mode;
              _stockQty = qty;
            });
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  Future<void> _openDateSheet() async {
    var day = _day;
    await showV2BottomSheet<void>(
      context,
      child: StatefulBuilder(
        builder: (context, setSheetState) => V2DateSheet(
          monthLabel: 'November 2026',
          days: <int?>[
            for (var blank = 0; blank < 6; blank++) null,
            for (var date = 1; date <= 30; date++) date,
          ],
          selectedDay: day,
          onSelect: (value) => setSheetState(() => day = value),
          onPrevMonth: () {},
          onNextMonth: () {},
          onConfirm: () {
            setState(() => _day = day);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        V2GallerySection(
          title: 'Warna',
          description: 'Palet v3 Royal dari Foundations/Color.',
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - V2Space.md) / 2;
                return Wrap(
                  spacing: V2Space.md,
                  runSpacing: V2Space.md,
                  children: [
                    for (final swatch in const [
                      V2ColorSwatch(
                        name: 'blue/500',
                        color: V2Colors.blue500,
                        caption: '#1565FF · aksi utama',
                      ),
                      V2ColorSwatch(
                        name: 'lime/400',
                        color: V2Colors.lime400,
                        caption: '#A3F533 · sorotan',
                      ),
                      V2ColorSwatch(
                        name: 'charcoal/900',
                        color: V2Colors.charcoal900,
                        caption: '#111827 · judul',
                      ),
                      V2ColorSwatch(
                        name: 'slate/500',
                        color: V2Colors.slate500,
                        caption: '#687280 · subjudul',
                      ),
                      V2ColorSwatch(
                        name: 'gray/50',
                        color: V2Colors.gray50,
                        caption: '#F6F8FA · latar',
                      ),
                      V2ColorSwatch(
                        name: 'gray/200',
                        color: V2Colors.gray200,
                        caption: '#E5E8EC · garis',
                      ),
                      V2ColorSwatch(
                        name: 'amber/500',
                        color: V2Colors.amber500,
                        caption: '#F59E0B · peringatan',
                      ),
                      V2ColorSwatch(
                        name: 'green/700',
                        color: V2Colors.green700,
                        caption: '#1F7A3D · sukses',
                      ),
                      V2ColorSwatch(
                        name: 'red/700',
                        color: V2Colors.red700,
                        caption: '#B3261E · error',
                      ),
                    ])
                      SizedBox(width: width, child: swatch),
                  ],
                );
              },
            ),
          ],
        ),
        V2GallerySection(
          title: 'Tipografi',
          description: 'Poppins, 9 langkah dari Foundations/Type.',
          children: const [
            V2TypeRow(
              name: 'Display',
              sample: 'Panen hari ini',
              spec: '34/40 Bold',
              style: V2Type.display,
            ),
            V2TypeRow(
              name: 'Value',
              sample: '12 pak',
              spec: '28/36 Bold',
              style: V2Type.value,
            ),
            V2TypeRow(
              name: 'H1',
              sample: 'Meja tanam',
              spec: '28/36 Bold',
              style: V2Type.h1,
            ),
            V2TypeRow(
              name: 'H2',
              sample: 'Benih selada',
              spec: '20/28 SemiBold',
              style: V2Type.h2,
            ),
            V2TypeRow(
              name: 'Body',
              sample: 'Stok benih Romaine tersisa 12 pak.',
              spec: '16/24 Regular',
              style: V2Type.body,
            ),
            V2TypeRow(
              name: 'Body Strong',
              sample: 'Stok benih Romaine',
              spec: '16/24 SemiBold',
              style: V2Type.bodyStrong,
            ),
            V2TypeRow(
              name: 'Button',
              sample: 'Simpan',
              spec: '16/24 SemiBold',
              style: V2Type.button,
            ),
            V2TypeRow(
              name: 'Label',
              sample: 'HSS 23',
              spec: '14/20 Medium',
              style: V2Type.label,
            ),
            V2TypeRow(
              name: 'Caption',
              sample: 'Diperbarui 08.30',
              spec: '12/16 Regular',
              style: V2Type.caption,
            ),
          ],
        ),
        V2GallerySection(
          title: 'Tombol',
          description: '5 tipe x 5 state. Grid 2 kolom.',
          children: [
            _pair(
              const V2Button(label: 'Primary'),
              const V2Button(label: 'Secondary', type: V2ButtonType.secondary),
            ),
            _pair(
              const V2Button(label: 'Tertiary', type: V2ButtonType.tertiary),
              const V2Button(label: 'Hapus', type: V2ButtonType.destructive),
            ),
            const V2Button(label: 'Ghost', type: V2ButtonType.ghost),
            _pair(
              const V2Button(label: 'Pressed', state: V2ButtonState.pressed),
              const V2Button(label: 'Disabled', state: V2ButtonState.disabled),
            ),
            _pair(
              const V2Button(label: 'Focus', state: V2ButtonState.focus),
              const V2Button(label: 'Proses', state: V2ButtonState.loading),
            ),
            V2Button(
              label: 'Simpan dengan ikon',
              icon: V2IconName.check,
              onPressed: () {},
            ),
          ],
        ),
        V2GallerySection(
          title: 'Input, select, dan cari',
          description: 'State default, focus, terisi, error, disabled.',
          children: [
            const V2TextField(label: 'Username', hint: 'Ketik username'),
            const V2TextField(
              label: 'Username (focus)',
              hint: 'Ketik username',
              forceFocus: true,
            ),
            V2TextField(
              label: 'Username (terisi)',
              controller: _filledController,
            ),
            const V2TextField(
              label: 'Username (error)',
              hint: 'Ketik username',
              error: 'Username wajib diisi.',
            ),
            const V2TextField(
              label: 'Username (disabled)',
              hint: 'Tidak dapat diubah',
              enabled: false,
            ),
            const V2PasswordField(),
            const V2SelectField(label: 'Jenis barang', value: 'Benih'),
            V2SearchField(
              controller: _searchController,
              hint: 'Cari barang',
              onClear: () => setState(_searchController.clear),
            ),
          ],
        ),
        V2GallerySection(
          title: 'Pilihan',
          description: 'OptionRow, chip filter, role chip, segmented.',
          children: [
            for (var index = 0; index < 3; index++) ...[
              if (index > 0) const SizedBox(height: V2Space.md),
              V2OptionRow(
                label: const ['Benih selada', 'Benih kangkung', 'Obat'][index],
                state: _option == index
                    ? V2OptionState.selected
                    : V2OptionState.normal,
                onTap: () => setState(() => _option = index),
              ),
            ],
            const V2OptionRow(
              label: 'Media rockwool (habis)',
              state: V2OptionState.disabled,
            ),
            Wrap(
              spacing: V2Space.sm,
              runSpacing: V2Space.sm,
              children: [
                for (final filter in const ['Semua', 'Menipis', 'Arsip'])
                  V2Chip(
                    label: filter,
                    selected: _filters.contains(filter),
                    onTap: () => setState(() {
                      if (_filters.contains(filter)) {
                        _filters.remove(filter);
                      } else {
                        _filters.add(filter);
                      }
                    }),
                  ),
              ],
            ),
            const Wrap(
              spacing: V2Space.sm,
              runSpacing: V2Space.sm,
              children: [
                V2RoleChip(label: 'Petani'),
                V2RoleChip(label: 'Pegawai', tone: V2RoleChipTone.neutral),
                V2RoleChip(label: 'Admin', tone: V2RoleChipTone.lime),
              ],
            ),
            V2Segmented(
              labels: const ['Bulan ini', 'Semua'],
              selectedIndex: _segmented,
              onChanged: (index) => setState(() => _segmented = index),
            ),
            V2Segmented(
              labels: const ['Kondisi', 'Prakiraan', 'Saran'],
              selectedIndex: _segmented3,
              onChanged: (index) => setState(() => _segmented3 = index),
            ),
            Center(child: V2Pagination(count: 3, index: _page)),
          ],
        ),
        V2GallerySection(
          title: 'Stepper dan jumlah',
          description: 'Stepper bulat 48 dan QtyField 56 dengan satuan.',
          children: [
            Center(
              child: V2Stepper(
                value: _qty,
                onMinus: () => setState(() => _qty = (_qty - 1).clamp(0, 99)),
                onPlus: () => setState(() => _qty += 1),
              ),
            ),
            V2QtyField(
              value: _qty,
              unit: 'pak',
              onMinus: () => setState(() => _qty = (_qty - 1).clamp(0, 99)),
              onPlus: () => setState(() => _qty += 1),
            ),
            V2QtyField(value: 0, unit: 'pak', enabled: false),
          ],
        ),
        V2GallerySection(
          title: 'Status',
          description: 'Badge 6 status, banner 5 tipe, toast 3 tipe.',
          children: [
            const Wrap(
              spacing: V2Space.sm,
              runSpacing: V2Space.sm,
              children: [
                V2Badge(label: 'Aman', status: V2BadgeStatus.success),
                V2Badge(label: 'Stok menipis', status: V2BadgeStatus.warning),
                V2Badge(label: 'Rusak', status: V2BadgeStatus.error),
                V2Badge(label: 'Offline', status: V2BadgeStatus.info),
                V2Badge(label: 'Kosong', status: V2BadgeStatus.neutral),
                V2Badge(
                  label: 'Menunggu sinkron',
                  status: V2BadgeStatus.pending,
                ),
              ],
            ),
            const V2Banner(message: 'Offline. Data tersimpan di HP.'),
            const V2Banner(
              message: '3 data menunggu sinkron',
              tone: V2BannerTone.sync,
            ),
            const V2Banner(
              message: 'Cuaca BMKG tidak tersedia',
              tone: V2BannerTone.bmkg,
            ),
            const V2Banner(
              message: 'Saran AI membantu. Keputusan tetap di tangan petani.',
              tone: V2BannerTone.ai,
            ),
            const V2Banner(message: 'Tersimpan', tone: V2BannerTone.success),
            const V2Toast(message: 'Tersimpan'),
            const V2Toast(message: 'Gagal menyimpan', tone: V2ToastTone.error),
            const V2Toast(message: 'Sinkron selesai', tone: V2ToastTone.info),
          ],
        ),
        V2GallerySection(
          title: 'Navigasi',
          description: 'StatusBar, AppBar, ScreenHeader, TabBar.',
          children: [
            Container(
              decoration: BoxDecoration(
                color: V2Colors.canvas,
                borderRadius: BorderRadius.circular(V2Radius.sm),
                border: Border.all(color: V2Colors.border),
              ),
              child: const Column(
                children: [
                  V2StatusBar(),
                  V2AppBar(title: 'Stok'),
                ],
              ),
            ),
            const V2ScreenHeader(
              title: 'Halo, Budi',
              subtitle: 'Siklus berjalan · Meja A2',
            ),
            Row(
              children: [
                const V2IconButton(
                  icon: V2IconName.bell,
                  semanticLabel: 'Notifikasi',
                ),
                const SizedBox(width: V2Space.sm),
                const V2IconButton(
                  icon: V2IconName.plus,
                  tone: V2IconButtonTone.soft,
                  semanticLabel: 'Tambah',
                ),
                const SizedBox(width: V2Space.sm),
                const V2IconButton(
                  icon: V2IconName.camera,
                  tone: V2IconButtonTone.filled,
                  semanticLabel: 'Kamera',
                ),
                const Spacer(),
                const V2IconButton(
                  icon: V2IconName.more,
                  semanticLabel: 'Lainnya',
                ),
              ],
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(V2Radius.card),
              ),
              child: V2TabBar(
                items: const [
                  V2TabItem(label: 'Beranda', icon: V2IconName.home),
                  V2TabItem(label: 'Tanam', icon: V2IconName.sprout),
                  V2TabItem(label: 'Stok', icon: V2IconName.box),
                  V2TabItem(label: 'Rawat', icon: V2IconName.care),
                  V2TabItem(label: 'Lainnya', icon: V2IconName.more),
                ],
                activeIndex: _tab,
                onTap: (index) => setState(() => _tab = index),
              ),
            ),
          ],
        ),
        V2GallerySection(
          title: 'Kartu dan daftar',
          description: 'Card, ListItem, StockItem, SummaryCard, BentoTile.',
          children: [
            const V2Card(
              title: 'Judul kartu',
              body: 'Isi singkat yang menjelaskan keadaan saat ini.',
            ),
            const V2ListItem(
              icon: V2IconName.sprout,
              title: 'Benih Romaine',
              subtitle: '12 pak',
            ),
            const V2Card(
              padding: EdgeInsets.symmetric(vertical: V2Space.xs),
              child: Column(
                children: [
                  V2StockItem(
                    title: 'Benih Romaine',
                    subtitle: 'Benih',
                    quantity: '12 pak',
                  ),
                  V2StockItem(
                    title: 'Benih Butterhead',
                    subtitle: 'Benih',
                    quantity: '2 pak',
                    badge: V2Badge(
                      label: 'Menipis',
                      status: V2BadgeStatus.warning,
                    ),
                    divider: true,
                  ),
                  V2StockItem(
                    title: 'Rockwool',
                    subtitle: 'Media',
                    quantity: '0 lembar',
                    icon: V2IconName.layers,
                    badge: V2Badge(label: 'Habis', status: V2BadgeStatus.error),
                    divider: true,
                  ),
                ],
              ),
            ),
            const V2SummaryCard(
              kicker: 'Benih Romaine, benih',
              value: '12 pak',
              meta: 'Minimum 3 pak',
              extra: 'Stok terpakai: Benih Romaine 2 pak',
              badge: V2Badge(label: 'Aman', status: V2BadgeStatus.success),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - V2Space.md) / 2;
                return Wrap(
                  spacing: V2Space.md,
                  runSpacing: V2Space.md,
                  children: [
                    V2BentoTile(
                      value: '2',
                      label: 'Stok menipis',
                      icon: V2IconName.box,
                      tone: V2BentoTone.warning,
                      size: width,
                    ),
                    V2BentoTile(
                      value: '400',
                      label: 'Lubang terisi',
                      icon: V2IconName.sprout,
                      size: width,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        V2GallerySection(
          title: 'Data dan siklus',
          description: 'WeatherCard, CycleCard, TimelineStep, Checklist.',
          children: [
            const V2WeatherCard(
              title: 'Berawan, 29°C',
              subtitle: 'Hujan 14.00',
            ),
            const V2CycleCard(
              kicker: 'Siklus berjalan',
              title: 'Meja A2',
              subtitle: '37 hari lagi',
            ),
            const V2TimelineStep(
              title: 'Semai',
              subtitle: 'HSS 1 sampai 15. Selesai',
              state: V2TimelineState.done,
            ),
            const V2TimelineStep(
              title: 'Tumbuh',
              subtitle: 'HSS 16 sampai 60. Berjalan',
              state: V2TimelineState.active,
            ),
            const V2TimelineStep(
              title: 'Panen',
              subtitle: 'Menunggu siap panen',
              state: V2TimelineState.pending,
              isLast: true,
            ),
            const V2Checklist(
              title: 'Mulai kebun',
              items: [
                V2ChecklistItem(
                  title: 'Tambah meja',
                  subtitle: '1 dari 3 selesai',
                  icon: V2IconName.layers,
                ),
                V2ChecklistItem(
                  title: 'Semai benih',
                  subtitle: 'Belum dimulai',
                  icon: V2IconName.sprout,
                ),
                V2ChecklistItem(
                  title: 'Catat stok',
                  subtitle: 'Belum dimulai',
                  icon: V2IconName.box,
                ),
              ],
            ),
          ],
        ),
        V2GallerySection(
          title: 'Grid dan diagram',
          description: 'GridCard, HoleGrid, ChartBar, Pagination.',
          children: [
            const V2GridCard(
              name: 'Meja A2',
              summary: '40 dari 240 lubang terisi',
              filled: 40,
              total: 240,
              badge: V2Badge(label: 'Aman', status: V2BadgeStatus.success),
            ),
            const V2Card(
              title: 'HoleGrid 12 x 8',
              child: V2HoleGrid(filled: 40, total: 96),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: const [
                Expanded(
                  child: V2ChartBar(value: '240', label: '6 Nov'),
                ),
                Expanded(
                  child: V2ChartBar(
                    value: '180',
                    label: '7 Nov',
                    barHeight: 56,
                  ),
                ),
                Expanded(
                  child: V2ChartBar(
                    value: '120',
                    label: '8 Nov',
                    barHeight: 36,
                  ),
                ),
                Expanded(
                  child: V2ChartBar(
                    value: '60',
                    label: '9 Nov',
                    barHeight: 20,
                    color: V2Colors.lime400,
                  ),
                ),
              ],
            ),
            Center(child: V2Pagination(count: 3, index: _page)),
          ],
        ),
        V2GallerySection(
          title: 'Ikon',
          description: '27 ikon garis 24px yang dipakai design system v2.',
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 2 * V2Space.md) / 3;
                return Wrap(
                  spacing: V2Space.md,
                  runSpacing: V2Space.md,
                  children: [
                    for (final name in V2IconName.values)
                      SizedBox(
                        width: width,
                        child: Column(
                          children: [
                            V2Icon(name, color: V2Colors.ink),
                            const SizedBox(height: V2Space.xs),
                            Text(
                              name.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: V2Type.caption.copyWith(
                                color: V2Colors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
        V2GallerySection(
          title: 'Skeleton',
          description: 'Placeholder pemuatan.',
          children: const [
            V2Skeleton.line(width: 240),
            V2Skeleton.block(height: 64),
            Row(
              children: [
                V2Skeleton.circle(size: 48),
                SizedBox(width: V2Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      V2Skeleton.line(width: 180),
                      SizedBox(height: V2Space.sm),
                      V2Skeleton.line(width: 120, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        V2GallerySection(
          title: 'Keadaan kosong dan gagal',
          description: 'ErrorState dengan slot ilustrasi.',
          children: [
            V2ErrorState(
              title: 'Gagal memuat stok',
              body:
                  'Periksa koneksi lalu coba lagi. Data yang tersimpan di '
                  'HP tetap aman.',
              actionLabel: 'Coba lagi',
              onAction: () {},
            ),
          ],
        ),
        V2GallerySection(
          title: 'Overlay',
          description: 'Dialog konfirmasi dan tiga bottom sheet.',
          children: [
            V2Button(
              label: 'Buka dialog konfirmasi',
              type: V2ButtonType.tertiary,
              onPressed: () => showV2Dialog(
                context,
                title: 'Simpan perubahan?',
                body: 'Data akan diperbarui.',
                secondaryLabel: 'Batal',
              ),
            ),
            V2Button(
              label: 'Buka sheet pilihan',
              type: V2ButtonType.tertiary,
              onPressed: _openPickSheet,
            ),
            V2Button(
              label: 'Buka sheet catat stok',
              type: V2ButtonType.tertiary,
              onPressed: _openStockSheet,
            ),
            V2Button(
              label: 'Buka sheet tanggal',
              type: V2ButtonType.tertiary,
              onPressed: _openDateSheet,
            ),
            Text(
              'Pilihan terakhir: ${_picked == null
                  ? '-'
                  : _picked == 0
                  ? 'Benih'
                  : _picked == 1
                  ? 'Nutrisi'
                  : _picked == 2
                  ? 'Media'
                  : 'Obat'} · '
              'tanggal $_day · stok $_stockQty',
              style: V2Type.caption.copyWith(color: V2Colors.muted),
            ),
          ],
        ),
        V2GallerySection(
          title: 'FlowNote',
          description: 'Catatan alur di atas tiap halaman fitur.',
          children: const [
            V2FlowNote(
              title: '04 Inventaris',
              note:
                  'Stok, tambah barang, catat stok, arsip, dan konflik data. '
                  'Petani dan pegawai.',
              roleLabel: 'Semua peran',
            ),
          ],
        ),
      ],
    );
  }
}
