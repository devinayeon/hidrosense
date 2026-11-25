import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/models/sync_queue_item.dart';
import '../../../data/services/notification_permission_service.dart';
import '../../../viewmodels/v2_penjualan_store.dart';
import '../../../viewmodels/v2_sync_queue.dart';
import '../../../viewmodels/v2_sync_replayer.dart';
import '../components/v2_auth_assets.dart';
import '../components/v2_penjualan_data.dart';
import '../components/v2_sinkron_data.dart';
import '../components/v2_sinkron_notif_card.dart';
import '../components/v2_sinkron_row.dart';
import '../components/v2_sinkron_skeleton.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_action_bar.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_badge.dart';
import '../widgets/v2_banner.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_dialog.dart';
import '../widgets/v2_group_list.dart';
import '../widgets/v2_summary_card.dart';
import 'v2_penjualan_form_page.dart';

/// Menjalankan satu putaran sinkron dan melaporkan kemajuannya.
typedef V2SyncNow =
    Future<V2SyncRun> Function(
      void Function(V2SyncProgress progress) onProgress,
    );

/// Menyelesaikan satu baris konflik menurut pilihan dialog 11.8.
typedef V2SyncConflictAction =
    Future<void> Function(String key, {required bool useServer});

/// Sambungan Beranda ke jam sinkron nyata: jam yang sudah diketahui, cara
/// menyegarkannya dari server, cara mencatat sinkron yang baru selesai, dan
/// putaran sinkron yang ikut mencatat jam. Null di galeri.
class V2SyncLink {
  const V2SyncLink({
    required this.refresh,
    required this.record,
    this.lastSyncedAt,
    this.syncNow,
  });

  final DateTime? lastSyncedAt;
  final Future<DateTime?> Function() refresh;
  final Future<DateTime> Function() record;

  /// Putaran sinkron yang mencatat jam; null berarti memakai pengirim biasa.
  final V2SyncNow? syncNow;
}

/// Keadaan halaman sinkron yang punya frame sendiri di page 11.
enum V2SinkronState {
  /// Frame 11.1: semua data sudah di server.
  ready,

  /// Frame 11.2: rangka kartu sebelum status tampil.
  loading,

  /// Frame 11.3: izin notifikasi dimatikan.
  notifOff,

  /// Frame 11.4: perangkat offline, semua data masih antre.
  offline,

  /// Frame 11.5: pengiriman sedang berjalan.
  syncing,

  /// Frame 11.6: pengiriman selesai, antrean kosong.
  done,

  /// Frame 11.7: sebagian data ditolak server.
  partial,

  /// Frame 11.8: dialog konflik data terbuka di atas 11.7.
  conflict,

  /// Frame 11.10: sesi berakhir, minta masuk lagi.
  sessionExpired,
}

/// Halaman Sinkron: frame 11.1 (terkini), 11.2 (memuat), 11.3 (notifikasi
/// mati), 11.4 (offline), 11.5 (berjalan), 11.6 (selesai), 11.7 (gagal
/// sebagian), 11.8 (konflik data), dan 11.10 (sesi berakhir).
///
/// "Sinkron sekarang" menjalankan pengiriman contoh: banner "Mengirim 3 dari
/// 5 data" tampil sebentar, lalu ringkasan berganti ke 11.6 dengan toast.
/// Bila halaman diberi antrean dan pengirim nyata, banner memakai jumlah baris
/// sungguhan dan hasilnya menentukan 11.6/11.7. Pada 11.7, baris Penjualan
/// membuka form perbaikan 11.9 dan baris Rusak membuka dialog 11.8.
class V2SinkronPage extends StatefulWidget {
  const V2SinkronPage({
    super.key,
    this.state = V2SinkronState.ready,
    this.toast,
    this.items,
    this.queue,
    this.onSyncNow,
    this.onResolveConflict,
    this.saleRepairer,
    this.lastSyncedAt,
    this.refreshLastSync,
    this.recordSync,
  });

  /// Frame `11.2 Memuat status sinkron`.
  const V2SinkronPage.loading({super.key})
    : state = V2SinkronState.loading,
      toast = null,
      items = null,
      queue = null,
      onSyncNow = null,
      onResolveConflict = null,
      saleRepairer = null,
      lastSyncedAt = null,
      refreshLastSync = null,
      recordSync = null;

  /// Frame `11.3 Izin notifikasi mati`.
  const V2SinkronPage.notifOff({super.key})
    : state = V2SinkronState.notifOff,
      toast = null,
      items = null,
      queue = null,
      onSyncNow = null,
      onResolveConflict = null,
      saleRepairer = null,
      lastSyncedAt = null,
      refreshLastSync = null,
      recordSync = null;

  /// Frame `11.4 Antrean, tanpa internet`.
  const V2SinkronPage.offline({super.key})
    : state = V2SinkronState.offline,
      toast = null,
      items = null,
      queue = null,
      onSyncNow = null,
      onResolveConflict = null,
      saleRepairer = null,
      lastSyncedAt = null,
      refreshLastSync = null,
      recordSync = null;

  /// Frame `11.5 Sinkron berjalan`.
  const V2SinkronPage.syncing({super.key})
    : state = V2SinkronState.syncing,
      toast = null,
      items = null,
      queue = null,
      onSyncNow = null,
      onResolveConflict = null,
      saleRepairer = null,
      lastSyncedAt = null,
      refreshLastSync = null,
      recordSync = null;

  /// Frame `11.6 Sinkron selesai`.
  const V2SinkronPage.done({super.key})
    : state = V2SinkronState.done,
      toast = 'Sinkron selesai',
      items = null,
      queue = null,
      onSyncNow = null,
      onResolveConflict = null,
      saleRepairer = null,
      lastSyncedAt = null,
      refreshLastSync = null,
      recordSync = null;

  /// Frame `11.7 Sinkron gagal sebagian`.
  const V2SinkronPage.partial({super.key})
    : state = V2SinkronState.partial,
      toast = null,
      items = null,
      queue = null,
      onSyncNow = null,
      onResolveConflict = null,
      saleRepairer = null,
      lastSyncedAt = null,
      refreshLastSync = null,
      recordSync = null;

  /// Frame `11.8 Konflik data`: dialog sudah terbuka saat halaman dibuka.
  const V2SinkronPage.conflict({super.key})
    : state = V2SinkronState.conflict,
      toast = null,
      items = null,
      queue = null,
      onSyncNow = null,
      onResolveConflict = null,
      saleRepairer = null,
      lastSyncedAt = null,
      refreshLastSync = null,
      recordSync = null;

  /// Frame `11.10 Sesi berakhir`: tanpa AppBar.
  const V2SinkronPage.sessionExpired({super.key})
    : state = V2SinkronState.sessionExpired,
      toast = null,
      items = null,
      queue = null,
      onSyncNow = null,
      onResolveConflict = null,
      saleRepairer = null,
      lastSyncedAt = null,
      refreshLastSync = null,
      recordSync = null;

  final V2SinkronState state;

  /// Toast yang sudah tampil saat halaman dibuka (frame 11.6).
  final String? toast;

  /// Baris antrean nyata dari HP (potret); null berarti data contoh galeri.
  final List<V2SinkronItem>? items;

  /// Antrean hidup; bila diisi, baris mengikuti isinya dan "Sinkron sekarang"
  /// mengirim ulang sungguhan. Null berarti galeri memakai simulasi.
  final V2SyncQueue? queue;

  /// Menjalankan pengiriman ulang; hasilnya menentukan keadaan setelah 11.5.
  /// [onProgress] melaporkan kemajuan tiap baris untuk banner 11.5.
  final V2SyncNow? onSyncNow;

  /// Menyelesaikan baris konflik: [useServer] true membuang isi HP, false
  /// menulis ulang isi HP dengan versi server terbaru. Null di galeri.
  final V2SyncConflictAction? onResolveConflict;

  /// Menyiapkan dan mengirim ulang penjualan yang ditolak server (11.9).
  /// Null berarti ketukan baris Penjualan hanya membuka pratinjau galeri.
  final V2PenjualanRepairer? saleRepairer;

  /// Jam sinkron terakhir yang diketahui saat halaman dibuka (disimpan di HP
  /// dan server). Null di galeri atau bila HP ini belum pernah sinkron.
  final DateTime? lastSyncedAt;

  /// Menyegarkan jam sinkron dari server begitu halaman terbuka, supaya jam
  /// yang tampil tidak bergantung pada kapan halaman ini terakhir dibuat.
  final Future<DateTime?> Function()? refreshLastSync;

  /// Mencatat sinkron yang selesai di luar putaran biasa (perbaikan baris
  /// atau penyelesaian konflik) dan mengembalikan jamnya.
  final Future<DateTime> Function()? recordSync;

  static Route<void> route({
    V2SinkronState state = V2SinkronState.ready,
    String? toast,
    List<V2SinkronItem>? items,
    V2SyncQueue? queue,
    V2SyncNow? onSyncNow,
    V2SyncConflictAction? onResolveConflict,
    V2PenjualanRepairer? saleRepairer,
    DateTime? lastSyncedAt,
    Future<DateTime?> Function()? refreshLastSync,
    Future<DateTime> Function()? recordSync,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => V2SinkronPage(
        state: state,
        toast: toast,
        items: items,
        queue: queue,
        onSyncNow: onSyncNow,
        onResolveConflict: onResolveConflict,
        saleRepairer: saleRepairer,
        lastSyncedAt: lastSyncedAt,
        refreshLastSync: refreshLastSync,
        recordSync: recordSync,
      ),
    );
  }

  @override
  State<V2SinkronPage> createState() => _V2SinkronPageState();
}

class _V2SinkronPageState extends State<V2SinkronPage> {
  late V2SinkronState _state = widget.state;
  Timer? _syncTimer;
  Timer? _toastTimer;
  String? _toast;

  /// Hasil putaran nyata, dipakai ringkasan 11.7.
  V2SyncRun? _lastRun;
  DateTime? _doneAt;

  /// Jam sinkron terakhir yang tampil di ringkasan 11.1; diisi dari HP saat
  /// halaman dibuka, disegarkan dari server, dan dimajukan tiap sinkron selesai.
  late DateTime? _lastSynced = widget.lastSyncedAt;

  /// Potret antrean saat tombol ditekan, supaya baris yang sudah terkirim
  /// tetap tampil "Terkirim" sampai keadaan berikutnya (frame 11.5).
  List<SyncQueueItem> _runItems = const [];
  Map<String, V2SinkronStatus> _runStatus = const {};
  int _syncCurrent = 1;
  int _syncTotal = 0;

  /// Satu sinkron contoh berjalan cepat; angka 11.5 dan hasil 11.6 galeri
  /// sudah ditentukan desain, bukan dihitung dari backend.
  static const Duration _syncDuration = Duration(milliseconds: 1400);

  @override
  void initState() {
    super.initState();
    _toast = widget.toast;
    if (_toast != null) _scheduleToastDismiss();
    unawaited(_refreshLastSync());
    if (_state == V2SinkronState.conflict) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showConflict());
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _toastTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshLastSync() async {
    final refresh = widget.refreshLastSync;
    if (refresh == null) return;
    final fresh = await refresh();
    if (!mounted || fresh == null) return;
    final current = _lastSynced;
    if (current == null || fresh.isAfter(current)) {
      setState(() => _lastSynced = fresh);
    }
  }

  /// Mencatat sinkron yang selesai di luar putaran biasa. Tanpa pencatat
  /// (galeri) jamnya jam perangkat; bila pencatatan gagal, jam perangkat juga
  /// yang dipakai karena datanya memang baru saja sampai ke server.
  Future<DateTime> _stampNow() async {
    final record = widget.recordSync;
    if (record != null) {
      try {
        return await record();
      } catch (_) {}
    }
    return DateTime.now();
  }

  void _scheduleToastDismiss() {
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  Future<void> _startSync() async {
    _syncTimer?.cancel();
    _toastTimer?.cancel();
    final onSyncNow = widget.onSyncNow;
    final queue = widget.queue;
    final snapshot = onSyncNow == null || queue == null
        ? const <SyncQueueItem>[]
        : List<SyncQueueItem>.unmodifiable(queue.items);
    setState(() {
      _state = V2SinkronState.syncing;
      _toast = null;
      _lastRun = null;
      _doneAt = null;
      _runItems = snapshot;
      _runStatus = const {};
      _syncCurrent = 1;
      _syncTotal = snapshot.length;
    });
    if (onSyncNow == null) {
      _syncTimer = Timer(_syncDuration, () {
        if (!mounted) return;
        setState(() {
          _state = V2SinkronState.done;
          _toast = 'Sinkron selesai';
          _doneAt = DateTime.now();
          _lastSynced = _doneAt;
        });
        _scheduleToastDismiss();
      });
      return;
    }
    final run = await onSyncNow(_onProgress);
    if (!mounted) return;
    setState(() {
      _lastRun = run;
      if (run.remaining == 0) {
        _state = V2SinkronState.done;
        _toast = 'Sinkron selesai';
        _doneAt = run.syncedAt ?? DateTime.now();
        _lastSynced = _doneAt;
      } else if (run.sent == 0 && run.pending > 0) {
        _state = V2SinkronState.offline;
      } else {
        _state = V2SinkronState.partial;
      }
    });
    _scheduleToastDismiss();
  }

  /// Menandai baris yang baru selesai supaya daftar 11.5 ikut berubah.
  void _onProgress(V2SyncProgress progress) {
    if (!mounted) return;
    final status = switch (progress.stage) {
      V2SyncProgressStage.terkirim => V2SinkronStatus.terkirim,
      V2SyncProgressStage.gagal => V2SinkronStatus.gagal,
      _ => null,
    };
    setState(() {
      _syncCurrent = progress.current;
      _syncTotal = progress.total;
      if (status != null) {
        _runStatus = {..._runStatus, progress.item.key: status};
      }
    });
  }

  /// Teks banner 11.5: angka nyata bila halaman disambungkan, contoh di galeri.
  String get _progressLabel => widget.onSyncNow == null
      ? 'Mengirim 3 dari 5 data'
      : 'Mengirim $_syncCurrent dari $_syncTotal data';

  /// Ringkasan 11.7 dari hasil putaran terakhir.
  V2SinkronRingkasan get _partialRingkasan {
    final run = _lastRun;
    if (run == null || widget.onSyncNow == null) return designSinkronSebagian;
    return v2SinkronRingkasanSebagian(
      sent: run.sent,
      remaining: run.remaining,
      failed: run.failed,
    );
  }

  /// Ringkasan 11.6; galeri tetap memakai jam contoh frame.
  V2SinkronRingkasan get _doneRingkasan {
    final doneAt = _doneAt;
    if (doneAt == null || !_connected) return designSinkronSelesai;
    return v2SinkronRingkasanSelesai(doneAt);
  }

  /// Halaman tersambung ke antrean atau jam sinkron nyata; galeri tidak.
  /// Hanya halaman tersambung yang boleh menampilkan jam sungguhan, supaya
  /// jam contoh desain tidak pernah muncul di aplikasi.
  bool get _connected =>
      widget.onSyncNow != null ||
      widget.queue != null ||
      widget.lastSyncedAt != null ||
      widget.refreshLastSync != null;

  /// Ringkasan 11.1: jam nyata bila tersambung, jam contoh hanya di galeri.
  V2SinkronRingkasan get _readyRingkasan => _connected
      ? v2SinkronRingkasanTerkini(_lastSynced)
      : designSinkronTerkini;

  /// Form 11.9 untuk baris Penjualan: isian nyata bila antrean tersambung,
  /// pratinjau galeri bila tidak.
  Future<void> _openFix(V2SinkronItem row) async {
    final repairer = widget.saleRepairer;
    final queueItem = _queueItemOf(row.kunci);
    if (repairer == null || queueItem == null) {
      await Navigator.of(context).push<V2Penjualan>(
        MaterialPageRoute<V2Penjualan>(
          builder: (_) => V2PenjualanFormPage.fix(
            penjualanWarungSari.copyWith(sync: V2PenjualanSync.antrean),
          ),
        ),
      );
      return;
    }
    final V2PenjualanRepair? repair;
    try {
      repair = await repairer.prepare(queueItem);
    } catch (_) {
      if (!mounted) return;
      _flash('Penjualan belum bisa dimuat. Coba lagi.');
      return;
    }
    if (!mounted) return;
    if (repair == null) {
      _flash('Baris ini belum bisa diperbaiki dari HP.');
      return;
    }
    final updated = await Navigator.of(context).push<V2Penjualan>(
      MaterialPageRoute<V2Penjualan>(
        builder: (_) => V2PenjualanFormPage(
          initial: repair!.sale,
          fixing: true,
          panen: repair.panen,
          store: V2PenjualanQueueStore(repairer, queueItem),
        ),
      ),
    );
    if (updated == null || !mounted) return;
    unawaited(_afterRepair());
  }

  /// Baris antrean yang sedang tampil, dicari lewat kunci idempotennya.
  SyncQueueItem? _queueItemOf(String? key) {
    if (key == null) return null;
    for (final item in widget.queue?.items ?? const <SyncQueueItem>[]) {
      if (item.key == key) return item;
    }
    return null;
  }

  /// Setelah satu baris diperbaiki: 11.6 bila antrean kosong, selain itu
  /// ringkasan 11.7 dihitung ulang dari hasil putaran sebelumnya.
  Future<void> _afterRepair() async {
    final queue = widget.queue;
    if (queue == null) return;
    if (queue.items.isEmpty) {
      final stamped = await _stampNow();
      if (!mounted) return;
      setState(() {
        _state = V2SinkronState.done;
        _toast = 'Sinkron selesai';
        _doneAt = stamped;
        _lastSynced = stamped;
        _lastRun = const V2SyncRun();
      });
      _scheduleToastDismiss();
      return;
    }
    final run = _lastRun;
    setState(() {
      _lastRun = run == null
          ? V2SyncRun(
              sent: 1,
              failed: queue.items.length,
              total: queue.items.length + 1,
            )
          : V2SyncRun(
              sent: run.sent + 1,
              failed: run.failed > 0 ? run.failed - 1 : 0,
              pending: run.pending,
              waiting: run.waiting,
              total: run.total,
            );
      _toast = 'Penjualan terkirim.';
    });
    _scheduleToastDismiss();
  }

  /// Toast singkat untuk kegagalan yang tidak mengubah keadaan halaman.
  void _flash(String message) {
    setState(() => _toast = message);
    _scheduleToastDismiss();
  }

  /// Dialog 11.8; [item] diisi baris yang benar-benar bentrok, jadi badan
  /// dialog menyebut data nyata (mis. "Penjualan Toko Baru").
  Future<void> _showConflict([V2SinkronItem? item]) async {
    final nama = item?.nama;
    final body = nama == null
        ? 'Rusak Meja A2 diubah di server setelah Anda mengubahnya di HP.'
        : '${item!.title} $nama diubah di server setelah Anda mengubahnya di HP.';
    final useServer = await showV2Dialog(
      context,
      title: 'Data berubah di server',
      body: body,
      primaryLabel: 'Pakai data server',
      secondaryLabel: 'Kirim ulang punya saya',
    );
    if (useServer == null) return;
    final resolve = widget.onResolveConflict;
    final key = item?.kunci;
    if (resolve == null || key == null) return;
    try {
      await resolve(key, useServer: useServer);
      if (!mounted) return;
      if (widget.queue?.items.isEmpty ?? false) {
        final stamped = await _stampNow();
        if (!mounted) return;
        setState(() {
          _state = V2SinkronState.done;
          _toast = 'Sinkron selesai';
          _doneAt = stamped;
          _lastSynced = stamped;
          _lastRun = const V2SyncRun();
        });
        _scheduleToastDismiss();
      } else if (widget.onSyncNow != null) {
        await _startSync();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _toast = 'Konflik belum selesai. Coba lagi.');
      _scheduleToastDismiss();
    }
  }

  bool get _sessionEnded => _state == V2SinkronState.sessionExpired;
  bool get _loading => _state == V2SinkronState.loading;

  bool get _showFooter => !_loading;

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
              if (!_sessionEnded)
                V2AppBar(
                  title: 'Sinkron',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
              Expanded(child: _buildBody()),
              if (_showFooter) _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_sessionEnded) return const _SessionEndedView();

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        V2Space.xl,
        V2Space.sm,
        V2Space.xl,
        V2Space.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: switch (_state) {
          V2SinkronState.loading => const [V2SinkronSkeleton()],
          V2SinkronState.notifOff => [
            _summary(_readyRingkasan),
            const SizedBox(height: V2Space.lg),
            const V2SinkronNotifCard(
              title: 'Notifikasi mati',
              body: 'Pengingat HSS 15 tidak muncul.',
            ),
            const SizedBox(height: V2Space.lg),
            V2Button(
              label: 'Buka pengaturan',
              type: V2ButtonType.tertiary,
              onPressed: _openNotificationSettings,
            ),
          ],
          V2SinkronState.offline => [
            const V2Banner(message: 'Offline. Data tersimpan di HP.'),
            const SizedBox(height: V2Space.lg),
            _queueList(widget.items ?? designSinkronAntrean),
          ],
          V2SinkronState.syncing => [
            V2Banner(message: _progressLabel, tone: V2BannerTone.sync),
            const SizedBox(height: V2Space.lg),
            _runList(),
          ],
          V2SinkronState.partial || V2SinkronState.conflict => [
            _summary(_partialRingkasan),
            const SizedBox(height: V2Space.lg),
            _queueList(widget.items ?? designSinkronGagal, actionable: true),
          ],
          V2SinkronState.done => [_summary(_doneRingkasan)],
          V2SinkronState.ready => [_summary(_readyRingkasan)],
          V2SinkronState.sessionExpired => const [],
        },
      ),
    );
  }

  Widget _summary(V2SinkronRingkasan ringkasan) {
    return V2SummaryCard(
      kicker: ringkasan.kicker,
      value: ringkasan.value,
      meta: ringkasan.meta,
      extra: ringkasan.extra,
      badge: V2Badge(
        label: ringkasan.badgeLabel,
        status: switch (ringkasan.tone) {
          V2SinkronRingkasanTone.gagal => V2BadgeStatus.error,
          V2SinkronRingkasanTone.antrean => V2BadgeStatus.pending,
          V2SinkronRingkasanTone.terkini => V2BadgeStatus.success,
        },
      ),
    );
  }

  /// Daftar 11.5: potret antrean saat mulai, dengan status per baris.
  Widget _runList() {
    if (widget.onSyncNow == null || widget.queue == null) {
      return _list(designSinkronBerjalan);
    }
    return _list(v2SinkronItemsWithStatus(_runItems, _runStatus));
  }

  /// Daftar baris sinkron; mengikuti antrean hidup bila halaman disambungkan.
  Widget _queueList(List<V2SinkronItem> fallback, {bool actionable = false}) {
    final queue = widget.queue;
    if (queue == null) return _list(fallback, actionable: actionable);
    return StreamBuilder<List<SyncQueueItem>>(
      stream: queue.stream,
      initialData: queue.items,
      builder: (context, snapshot) => _list(
        v2SinkronItemsFromQueue(snapshot.data ?? queue.items),
        actionable: actionable,
      ),
    );
  }

  Widget _list(List<V2SinkronItem> items, {bool actionable = false}) {
    return V2GroupList(
      children: [
        for (final item in items)
          V2SinkronRow(item: item, onTap: actionable ? _actionFor(item) : null),
      ],
    );
  }

  /// Aksi baris 11.7: bentrok versi membuka 11.8, penjualan ditolak membuka
  /// form perbaikan, dan baris Rusak memakai contoh dialog desain.
  VoidCallback? _actionFor(V2SinkronItem item) {
    if (item.konflik) return () => _showConflict(item);
    return switch (item.jenis) {
      V2SinkronJenis.penjualan => () => _openFix(item),
      V2SinkronJenis.rusak => () => _showConflict(item),
      _ => null,
    };
  }

  void _openNotificationSettings() {
    NotificationPermissionService.openSettings();
  }

  Widget _buildFooter() {
    return switch (_state) {
      V2SinkronState.offline => V2ActionBar(
        note: 'Sinkron butuh internet. Data aman di HP.',
        actions: [
          V2Button(
            label: 'Sinkron sekarang',
            state: widget.onSyncNow == null
                ? V2ButtonState.disabled
                : V2ButtonState.normal,
            onPressed: widget.onSyncNow == null ? null : _startSync,
          ),
        ],
      ),
      V2SinkronState.syncing => const V2ActionBar(
        actions: [V2Button(label: 'Mengirim...', state: V2ButtonState.loading)],
      ),
      V2SinkronState.partial || V2SinkronState.conflict => V2ActionBar(
        toast: _toast,
        actions: [V2Button(label: 'Coba lagi', onPressed: _startSync)],
      ),
      V2SinkronState.sessionExpired => V2ActionBar(
        actions: [
          V2Button(
            label: 'Masuk lagi',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
      V2SinkronState.loading => const SizedBox.shrink(),
      _ => V2ActionBar(
        toast: _toast,
        actions: [V2Button(label: 'Sinkron sekarang', onPressed: _startSync)],
      ),
    };
  }
}

/// Isi frame 11.10: ilustrasi 160, judul, dan badan dipusatkan di atas footer.
///
/// Frame aslinya menaruh konten pada kotak 560 dengan sisa 70 di bawahnya;
/// sisa itu artefak bingkai, jadi di sini konten benar-benar dipusatkan.
class _SessionEndedView extends StatelessWidget {
  const _SessionEndedView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          V2Space.xl,
          V2Space.lg,
          V2Space.xl,
          V2Space.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Image.asset(
                V2AuthAssets.inactiveAccount,
                width: 160,
                height: 160,
                filterQuality: FilterQuality.medium,
              ),
            ),
            const SizedBox(height: V2Space.lg),
            Text(
              'Sesi berakhir',
              textAlign: TextAlign.center,
              style: V2Type.h1,
            ),
            const SizedBox(height: V2Space.lg),
            Text(
              'Masuk lagi. Data di HP tetap aman dan terkirim setelah masuk.',
              textAlign: TextAlign.center,
              style: V2Type.body.copyWith(color: V2Colors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
