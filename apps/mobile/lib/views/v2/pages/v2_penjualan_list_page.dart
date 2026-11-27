import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/business_date.dart';
import '../../../data/models/sync_queue_item.dart';
import '../../../viewmodels/session_viewmodel.dart';
import '../../../viewmodels/v2_penjualan_mappers.dart';
import '../../../viewmodels/v2_penjualan_store.dart';
import '../../../viewmodels/v2_sync_queue.dart';
import '../components/v2_penjualan_assets.dart';
import '../components/v2_penjualan_data.dart';
import '../components/v2_penjualan_row.dart';
import '../components/v2_penjualan_skeleton.dart';
import '../components/v2_penjualan_store.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_action_bar.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_banner.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_error_state.dart';
import '../widgets/v2_group_list.dart';
import '../widgets/v2_icon.dart';
import '../widgets/v2_icon_button.dart';
import '../widgets/v2_summary_card.dart';
import 'v2_penjualan_detail_page.dart';
import 'v2_penjualan_form_page.dart';
import 'v2_penjualan_summary_page.dart';

/// Keadaan daftar penjualan yang punya frame sendiri di page 08.
enum V2PenjualanListState {
  /// Frame 8.1/8.6: daftar siap.
  ready,

  /// Frame 8.2: rangka kartu sebelum daftar tampil.
  loading,

  /// Frame 8.3: muat daftar gagal.
  error,

  /// Frame 8.4: belum ada satu pun penjualan.
  empty,

  /// Frame 8.14: penjualan baru saja dicatat.
  created,

  /// Frame 8.16: perangkat offline, satu penjualan masih antre.
  offline,
}

/// Daftar penjualan: frame 8.1 (siap), 8.2 (memuat), 8.3 (gagal memuat),
/// 8.4 (kosong), 8.14 (penjualan dicatat), dan 8.16 (tersimpan di HP).
///
/// Susunan siap: kartu ringkasan bulan lalu `Grup daftar`. Tombol di bawah
/// selalu "Catat penjualan"; ia membuka form 8.7. Ikon grafik di AppBar membuka
/// ringkasan 8.5.
class V2PenjualanListPage extends StatefulWidget {
  const V2PenjualanListPage({
    super.key,
    this.initialPenjualan,
    this.ringkasan = designRingkasanPenjualan,
    this.state = V2PenjualanListState.ready,
    this.toast,
    this.panen,
    this.store,
    this.syncQueue,
    this.saleRepairer,
  });

  /// Frame `8.2 Memuat penjualan`.
  V2PenjualanListPage.loading({super.key})
    : initialPenjualan = designPenjualan,
      ringkasan = designRingkasanPenjualan,
      state = V2PenjualanListState.loading,
      toast = null,
      panen = null,
      store = null,
      syncQueue = null,
      saleRepairer = null;

  /// Frame `8.3 Gagal memuat penjualan`.
  V2PenjualanListPage.error({super.key})
    : initialPenjualan = designPenjualan,
      ringkasan = designRingkasanPenjualan,
      state = V2PenjualanListState.error,
      toast = null,
      panen = null,
      store = null,
      syncQueue = null,
      saleRepairer = null;

  /// Frame `8.4 Belum ada penjualan`.
  const V2PenjualanListPage.empty({super.key})
    : initialPenjualan = const <V2Penjualan>[],
      ringkasan = designRingkasanPenjualan,
      state = V2PenjualanListState.empty,
      toast = null,
      panen = null,
      store = null,
      syncQueue = null,
      saleRepairer = null;

  /// Frame `8.14 Penjualan dicatat`.
  V2PenjualanListPage.created({super.key})
    : initialPenjualan = designPenjualanBaru,
      ringkasan = designRingkasanPenjualanBaru,
      state = V2PenjualanListState.created,
      toast = 'Penjualan dicatat',
      panen = null,
      store = null,
      syncQueue = null,
      saleRepairer = null;

  /// Frame `8.16 Tersimpan di HP`.
  V2PenjualanListPage.offline({super.key})
    : initialPenjualan = designPenjualanOffline,
      ringkasan = designRingkasanPenjualan,
      state = V2PenjualanListState.offline,
      toast = 'Tersimpan di HP',
      panen = null,
      store = null,
      syncQueue = null,
      saleRepairer = null;

  final List<V2Penjualan>? initialPenjualan;
  final V2PenjualanRingkasan ringkasan;
  final V2PenjualanListState state;

  /// Toast yang sudah tampil saat halaman dibuka (frame 8.14/8.16).
  final String? toast;

  /// Pilihan panen untuk form; null berarti memakai data contoh galeri.
  final List<V2PenjualanPanen>? panen;

  /// Backend penjualan; null berarti mode pratinjau (hanya di memori).
  final V2PenjualanStore? store;

  /// Antrean HP; baris yang punya perubahan tertunda diberi lencana "Antrean".
  /// Null berarti galeri tanpa antrean.
  final V2SyncQueue? syncQueue;

  /// Penyiap form 11.9 untuk penjualan yang masih di antrean; null berarti
  /// baris antrean hanya bisa dilihat.
  final V2PenjualanRepairer? saleRepairer;

  static Route<void> route({
    List<V2Penjualan>? initialPenjualan,
    V2PenjualanRingkasan ringkasan = designRingkasanPenjualan,
    String? toast,
    List<V2PenjualanPanen>? panen,
    V2PenjualanStore? store,
    V2SyncQueue? syncQueue,
    V2PenjualanRepairer? saleRepairer,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => V2PenjualanListPage(
        initialPenjualan: initialPenjualan,
        ringkasan: ringkasan,
        toast: toast,
        panen: panen,
        store: store,
        syncQueue: syncQueue,
        saleRepairer: saleRepairer,
      ),
    );
  }

  @override
  State<V2PenjualanListPage> createState() => _V2PenjualanListPageState();
}

class _V2PenjualanListPageState extends State<V2PenjualanListPage> {
  late List<V2Penjualan> _items = widget.initialPenjualan ?? designPenjualan;
  late V2PenjualanRingkasan _ringkasan = widget.ringkasan;
  late List<V2PenjualanPanen> _panenOptions = widget.panen ?? designPanen;
  Timer? _toastTimer;
  String? _toast;

  /// Daftar sedang dimuat dari backend.
  bool _fetching = false;

  /// Galat muat dari backend; null berarti aman.
  String? _loadError;

  /// Langganan antrean supaya lencana "Antrean" ikut berubah saat baris lepas.
  StreamSubscription<List<SyncQueueItem>>? _queueSub;

  bool get _loading =>
      _fetching || widget.state == V2PenjualanListState.loading;
  bool get _error =>
      _loadError != null || widget.state == V2PenjualanListState.error;
  bool get _emptyList => !_loading && !_error && _displayItems.isEmpty;
  bool get _offline => widget.state == V2PenjualanListState.offline;

  /// Ikon grafik hanya muncul saat daftar siap dibaca (frame 8.1/8.6/8.14/
  /// 8.16); di keadaan memuat, gagal, dan kosong slotnya dibiarkan kosong.
  bool get _showSummaryAction => !_loading && !_error && !_emptyList;

  /// Baris server dengan tanda sinkron dari antrean HP, ditambah penjualan
  /// baru yang belum terkirim (dirangkai dari payload antrean).
  List<V2Penjualan> get _displayItems {
    final queue = widget.syncQueue;
    if (queue == null || queue.items.isEmpty) return _items;
    final baru = <V2Penjualan>[];
    final queued = <String>{};
    for (final row in queue.items.reversed) {
      if (row.jenis != SyncQueueJenis.penjualan) continue;
      if (row.mode == SyncQueueMode.baru) {
        final sale = v2PenjualanFromQueue(row, _panenOptions);
        if (sale != null) baru.add(sale);
      } else {
        queued.add(row.target);
      }
    }
    return [
      ...baru,
      for (final item in _items)
        queued.contains(item.id)
            ? item.copyWith(sync: V2PenjualanSync.antrean)
            : item,
    ];
  }

  @override
  void initState() {
    super.initState();
    _toast = widget.toast;
    if (_toast != null) _scheduleToastDismiss();
    _queueSub = widget.syncQueue?.stream.listen((_) {
      if (mounted) setState(() {});
    });
    if (widget.store != null) _load();
  }

  /// Memuat daftar, pilihan panen, dan ringkasan bulan berjalan.
  ///
  /// Semua galat harus menutup kerangka pemuatan: galat tak terduga (mis.
  /// respons yang bentuknya berubah) tidak boleh meninggalkan layar di keadaan
  /// "memuat" selamanya.
  Future<void> _load() async {
    final store = widget.store;
    if (store == null) return;
    setState(() {
      _fetching = true;
      _loadError = null;
    });
    try {
      final snapshot = await store.load();
      if (!mounted) return;
      setState(() {
        _items = snapshot.items;
        _panenOptions = snapshot.panen;
        _ringkasan = _ringkasanFor(_displayItems);
      });
    } on V2PenjualanStoreException catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = serviceError(error));
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  /// Ringkasan menghitung penjualan bulan berjalan (Jakarta), termasuk baris
  /// antrean yang belum terkirim supaya angka cocok dengan daftar.
  V2PenjualanRingkasan _ringkasanFor(List<V2Penjualan> items) {
    final today = jakartaToday();
    final bulanIni = items
        .where(
          (item) =>
              item.tanggal.year == today.year &&
              item.tanggal.month == today.month,
        )
        .toList();
    return ringkasanPenjualan(bulanIni, kicker: formatBulanTahun(today));
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _queueSub?.cancel();
    super.dispose();
  }

  void _scheduleToastDismiss() {
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() => _toast = message);
    _scheduleToastDismiss();
  }

  Future<void> _openSummary() async {
    await Navigator.of(context).push(
      V2PenjualanSummaryPage.route(
        bulanan: widget.store == null
            ? null
            : ringkasanBulananPenjualan(_items, sekarang: jakartaToday()),
      ),
    );
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<V2Penjualan>(
      V2PenjualanFormPage.route(
        panen: _panenOptions,
        store: widget.store,
        // Alur nyata memakai hari ini; galeri tetap memakai tanggal contoh.
        initialDate: widget.store == null ? null : jakartaToday(),
      ),
    );
    if (created == null || !mounted) return;
    setState(() {
      _items = [created, ..._items];
      if (widget.store != null) _ringkasan = _ringkasanFor(_displayItems);
    });
    _showToast('Penjualan dicatat');
  }

  /// Baris antrean belum ada di server: ketukannya membuka form 11.9, bukan
  /// detail penjualan.
  void _openRow(V2Penjualan penjualan) {
    final key = v2QueueSaleKey(penjualan);
    if (key != null) {
      _openRepair(key);
      return;
    }
    _openDetail(penjualan);
  }

  /// Form 11.9 untuk penjualan baru yang masih di antrean HP.
  Future<void> _openRepair(String key) async {
    final repairer = widget.saleRepairer;
    SyncQueueItem? item;
    for (final row in widget.syncQueue?.items ?? const <SyncQueueItem>[]) {
      if (row.key == key) item = row;
    }
    if (repairer == null || item == null) {
      _showToast('Baris ini belum bisa diperbaiki dari HP.');
      return;
    }
    final V2PenjualanRepair? repair;
    try {
      repair = await repairer.prepare(item);
    } catch (_) {
      if (!mounted) return;
      _showToast('Penjualan belum bisa dimuat. Coba lagi.');
      return;
    }
    if (!mounted) return;
    if (repair == null) {
      _showToast('Baris ini belum bisa diperbaiki dari HP.');
      return;
    }
    final updated = await Navigator.of(context).push<V2Penjualan>(
      MaterialPageRoute<V2Penjualan>(
        builder: (_) => V2PenjualanFormPage(
          initial: repair!.sale,
          fixing: true,
          panen: repair.panen,
          store: V2PenjualanQueueStore(repairer, item!),
        ),
      ),
    );
    if (updated == null || !mounted) return;
    _showToast('Penjualan terkirim.');
    await _load();
  }

  Future<void> _openDetail(V2Penjualan penjualan) async {
    final updated = await Navigator.of(context).push<V2Penjualan>(
      V2PenjualanDetailPage.route(
        penjualan,
        panen: _panenOptions,
        store: widget.store,
      ),
    );
    if (updated == null || !mounted) return;
    setState(() {
      _items = [
        for (final item in _items)
          if (item.id == updated.id) updated else item,
      ];
      if (widget.store != null) _ringkasan = _ringkasanFor(_displayItems);
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
                title: 'Penjualan',
                onBack: () => Navigator.of(context).maybePop(),
                trailing: _showSummaryAction
                    ? V2IconButton(
                        icon: V2IconName.chart,
                        semanticLabel: 'Ringkasan',
                        onPressed: _openSummary,
                      )
                    : null,
              ),
              Expanded(child: _buildBody()),
              if (!_loading && !_error) _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: _scrollPadding,
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 100),
            SizedBox(height: V2Space.lg),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: V2Space.xl),
              child: V2PenjualanSkeleton(),
            ),
          ],
        ),
      );
    }

    if (_error) {
      return SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: _scrollPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 100),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
              child: V2ErrorState(
                title: 'Gagal memuat',
                body: _loadError ?? 'Periksa internet, lalu coba lagi.',
                actionLabel: 'Coba lagi',
                onAction: _load,
                illustration: Image.asset(
                  V2PenjualanAssets.offlineNoInternet,
                  width: 160,
                  height: 160,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_emptyList) {
      return SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: _scrollPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 100),
            const SizedBox(height: 80),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
              child: V2ErrorState(
                title: 'Belum ada penjualan',
                body: 'Catat penjualan pertama.',
                illustration: Image.asset(
                  V2PenjualanAssets.salesProduce,
                  width: 160,
                  height: 160,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final rows = _displayItems;
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: _scrollPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_offline) ...[
                  const V2Banner(message: 'Offline. Data tersimpan di HP.'),
                  const SizedBox(height: V2Space.lg),
                ],
                _buildSummary(),
              ],
            ),
          ),
          const SizedBox(height: V2Space.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
            child: V2GroupList(
              children: [
                for (final penjualan in rows)
                  V2PenjualanRow(
                    penjualan: penjualan,
                    onTap: () => _openRow(penjualan),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  EdgeInsets get _scrollPadding =>
      const EdgeInsets.only(top: V2Space.sm, bottom: V2Space.xl);

  Widget _buildSummary() {
    return V2SummaryCard(
      kicker: _ringkasan.kicker,
      value: _ringkasan.total,
      meta: _ringkasan.kgTerjual,
    );
  }

  Widget _buildFooter() {
    return V2ActionBar(
      toast: _toast,
      toastTone: _offline ? V2ToastTone.info : V2ToastTone.success,
      actions: [V2Button(label: 'Catat penjualan', onPressed: _openCreate)],
    );
  }
}
