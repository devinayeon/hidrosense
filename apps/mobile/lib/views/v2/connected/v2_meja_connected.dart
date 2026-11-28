import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/uuid.dart';
import '../../../data/models/inventory_record.dart';
import '../../../data/models/damage_record.dart';
import '../../../data/models/nursery_record.dart';
import '../../../data/models/table_record.dart';
import '../../../data/models/transfer_record.dart';
import '../../../viewmodels/connected_inventory_viewmodel.dart';
import '../../../viewmodels/connected_nursery_viewmodel.dart';
import '../../../viewmodels/connected_table_viewmodel.dart';
import '../../../viewmodels/damage_viewmodel.dart';
import '../../../viewmodels/panen_viewmodel.dart';
import '../../../viewmodels/session_viewmodel.dart';
import '../components/v2_meja_data.dart';
import '../components/v2_semaian_data.dart';
import '../pages/v2_meja_detail_page.dart';
import '../pages/v2_meja_form_page.dart';
import '../pages/v2_meja_list_page.dart';
import '../pages/v2_pilih_semaian_page.dart';
import '../pages/v2_pindah_meja_page.dart';
import 'v2_semaian_connected.dart';

/// Seluruh batch pemindahan, dipakai meja dan panen untuk membaca tanaman.
///
/// Gagal baca diperlakukan sebagai daftar kosong: daftar meja tetap tampil
/// walau pengguna tidak punya izin batch, hanya tanpa rincian tanaman.
final v2AllTransfersProvider = FutureProvider.autoDispose<List<TransferRecord>>(
  (ref) async {
    final user = ref.watch(sessionProvider.select((state) => state.user));
    if (user == null) return const <TransferRecord>[];
    try {
      return await ref.watch(harvestRepositoryProvider).listTransfers();
    } catch (_) {
      return const <TransferRecord>[];
    }
  },
);

/// Seluruh penyemaian untuk menerjemahkan batch menjadi nama benih.
final v2AllSowingsProvider = FutureProvider.autoDispose<List<SowingRecord>>((
  ref,
) async {
  final user = ref.watch(sessionProvider.select((state) => state.user));
  if (user == null) return const <SowingRecord>[];
  try {
    return await ref.watch(nurseryRepositoryProvider).listSowings();
  } catch (_) {
    return const <SowingRecord>[];
  }
});

/// Segarkan data setelah tulis pemindahan/tanaman/rusak (BUG-34): meja
/// (kapasitas & terisi), daftar pemindahan, dan daftar penyemaian dimuat ulang
/// supaya Detail meja, form "sisa", dan kartu Beranda memakai data terbaru.
///
/// [tableIds] kosong berarti menyegarkan semua meja.
Future<void> v2SegarkanSetelahTulis(
  WidgetRef ref, {
  Set<String> tableIds = const <String>{},
}) async {
  final tables = ref.read(connectedTableProvider.notifier);
  if (tableIds.isEmpty) {
    await tables.refresh();
  } else {
    for (final id in tableIds) {
      await tables.refreshTable(id);
    }
  }
  ref.invalidate(v2AllTransfersProvider);
  ref.invalidate(v2AllSowingsProvider);
  await ref.read(v2AllTransfersProvider.future);
  await ref.read(v2AllSowingsProvider.future);
}

/// `tersedia`/`penuh`/`pemeliharaan` backend → tiga keadaan desain page 06.
V2MejaStatus v2StatusMeja(TableRecord record) {
  if (record.isMaintenance || record.isInactive) return V2MejaStatus.perawatan;
  if (record.isFull) return V2MejaStatus.penuh;
  return V2MejaStatus.tersedia;
}

String? v2NamaVarietasTransfer(
  TransferRecord transfer,
  List<SowingRecord> sowings,
  List<InventoryRecord> inventaris,
) {
  final sowing = sowings
      .where((item) => item.id == transfer.sowingId)
      .firstOrNull;
  final material = sowing?.materials.firstOrNull;
  if (material == null) return null;
  final bahan = inventaris
      .where((item) => item.id == material.inventoryId)
      .firstOrNull;
  return bahan == null ? null : v2NamaBenih(bahan.name);
}

V2TanamanItem _tanamanFromTransfer(
  TransferRecord transfer, {
  required List<SowingRecord> sowings,
  required List<InventoryRecord> inventaris,
  required DateTime hariIni,
}) {
  final pindah = DateTime.tryParse(transfer.transferDate) ?? jakartaToday();
  final panen =
      DateTime.tryParse(transfer.estimatedHarvestDate ?? '') ??
      DateTime(pindah.year, pindah.month, pindah.day + v2MejaUmurPanenHst);
  return V2TanamanItem(
    varietas:
        v2NamaVarietasTransfer(transfer, sowings, inventaris) ?? 'Tanaman meja',
    tanggalTanam: pindah,
    tanggalPanen: panen,
    tanggalPindah: pindah,
    umurPanenHst: transfer.remainingHarvestDays == null || transfer.hst == null
        ? v2MejaUmurPanenHst
        : transfer.remainingHarvestDays! + transfer.hst!,
    hssPindah: transfer.hss ?? v2SemaianHssSiapPindah,
    jumlahAktif: transfer.activePlants,
    jumlahAwal: transfer.plantCount,
    keterangan: transfer.note,
    transferId: transfer.id,
    hariIni: hariIni,
  );
}

/// Satu laporan kerusakan backend → catatan page 06 (frame 6.24–6.29).
V2KerusakanItem v2KerusakanDariDamage(
  DamageRecord damage, {
  required String varietas,
  required String meja,
}) => V2KerusakanItem(
  id: damage.id,
  transferId: damage.transferId,
  jumlah: damage.plantCount,
  jenis: damage.category,
  tanggal: DateTime.tryParse(damage.date) ?? jakartaToday(),
  varietas: varietas,
  meja: meja,
  keterangan: damage.note,
);

/// Pemetaan satu meja backend ke model daftar/detail page 06.
///
/// [hariIni] mengisi acuan HST dan hitung mundur panen; bawaan hari ini WIB
/// supaya tanaman tersambung tidak memakai tanggal contoh (BUG-36).
V2MejaItem v2MejaItemFromRecord(
  TableRecord record, {
  List<TransferRecord> transfers = const <TransferRecord>[],
  List<SowingRecord> sowings = const <SowingRecord>[],
  List<InventoryRecord> inventaris = const <InventoryRecord>[],
  List<DamageRecord> damages = const <DamageRecord>[],
  DateTime? hariIni,
}) {
  final acuan = hariIni ?? jakartaToday();
  final tanaman = transfers
      .where((item) => item.tableId == record.id && item.activePlants > 0)
      .map(
        (item) => _tanamanFromTransfer(
          item,
          sowings: sowings,
          inventaris: inventaris,
          hariIni: acuan,
        ),
      )
      .toList();
  final rusak = damages.map((damage) {
    final transfer = transfers
        .where((item) => item.id == damage.transferId)
        .firstOrNull;
    final varietas = transfer == null
        ? 'Tanaman meja'
        : v2NamaVarietasTransfer(transfer, sowings, inventaris) ??
              'Tanaman meja';
    return v2KerusakanDariDamage(damage, varietas: varietas, meja: record.code);
  }).toList();
  return V2MejaItem(
    id: record.id,
    kode: record.code,
    jumlahLubang: record.holeCount,
    terisi: record.activePlants,
    status: v2StatusMeja(record),
    keterangan: record.notes,
    tanaman: tanaman,
    rusak: rusak,
  );
}

/// Rute Detail meja lewat pintu masuk bersama (BUG-39), dipakai
/// [bukaDetailMeja] dan alur yang mengganti halaman (mis. "Lihat meja" dari
/// halaman sukses "Pindah ke meja").
Route<void> detailMejaRoute({
  required String tableId,
  V2MejaItem? item,
  VoidCallback? onOpenSemaian,
}) {
  return MaterialPageRoute<void>(
    builder: (_) => V2MejaConnectedDetailPage(
      tableId: tableId,
      item: item,
      onOpenSemaian: onOpenSemaian,
    ),
  );
}

/// Pintu masuk bersama Detail meja (BUG-39).
///
/// Detail meja **selalu** dibuka lewat [tableId] supaya halamannya membaca
/// ulang dari provider (kapasitas, tanaman, kerusakan) dan tidak menyalin objek
/// yang bisa basi — baik dibuka dari daftar meja maupun dari halaman sukses
/// "Pindah ke meja". [item] hanya dipakai sebagai gambar awal supaya halaman
/// tidak kosong sesaat.
Future<void> bukaDetailMeja(
  NavigatorState navigator,
  String tableId, {
  V2MejaItem? item,
  VoidCallback? onOpenSemaian,
}) {
  return navigator.push<void>(
    detailMejaRoute(tableId: tableId, item: item, onOpenSemaian: onOpenSemaian),
  );
}

/// Isi segmen "Meja" di tab Tanam dengan data backend.
class V2MejaConnectedTab extends ConsumerWidget {
  const V2MejaConnectedTab({
    super.key,
    this.initialStatusIndex = 0,
    this.onSegmentChanged,
    this.onOpenSemaian,
  });

  final int initialStatusIndex;
  final ValueChanged<int>? onSegmentChanged;

  /// Kembali ke dashboard lalu membuka Semaian (diteruskan ke Detail meja).
  final VoidCallback? onOpenSemaian;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(connectedTableProvider);
    final transfers = ref.watch(v2AllTransfersProvider).valueOrNull ?? const [];
    final sowings = ref.watch(v2AllSowingsProvider).valueOrNull ?? const [];
    final inventaris = ref.watch(
      connectedInventoryProvider.select((value) => value.activeRecords),
    );
    final items = data.records
        .map(
          (record) => v2MejaItemFromRecord(
            record,
            transfers: transfers,
            sowings: sowings,
            inventaris: inventaris,
          ),
        )
        .toList();
    final viewState = switch (data) {
      TableState(loading: true) when items.isEmpty => V2MejaState.loading,
      TableState(error: _?) when items.isEmpty => V2MejaState.error,
      _ => V2MejaState.ready,
    };
    return V2MejaTabView(
      items: items,
      state: viewState,
      initialStatusIndex: initialStatusIndex,
      onSegmentChanged: onSegmentChanged,
      onRetry: () => ref.read(connectedTableProvider.notifier).refresh(),
      onRefresh: () async {
        await Future.wait([
          v2SegarkanSetelahTulis(ref),
          ref.read(connectedInventoryProvider.notifier).refresh(),
        ]);
      },
      onAdd: () => _tambah(context, ref),
      onTapItem: (item) => _bukaDetail(context, ref, item),
    );
  }

  Future<void> _bukaDetail(
    BuildContext context,
    WidgetRef ref,
    V2MejaItem item,
  ) {
    final id = item.id;
    if (id == null) {
      // Data contoh galeri/offline belum punya id; tetap tampilkan salinannya.
      return Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => V2MejaConnectedDetailPage(
            item: item,
            onOpenSemaian: onOpenSemaian,
          ),
        ),
      );
    }
    return bukaDetailMeja(
      Navigator.of(context),
      id,
      item: item,
      onOpenSemaian: onOpenSemaian,
    );
  }

  Future<void> _tambah(BuildContext context, WidgetRef ref) async {
    // Kode yang sudah ada ditolak di form sebelum ditutup, supaya isian tidak
    // hilang saat server menolak duplikat (K-14).
    final takenCodes = ref
        .read(connectedTableProvider)
        .records
        .map((table) => table.code.trim().toUpperCase())
        .where((code) => code.isNotEmpty)
        .toSet();
    final result = await Navigator.of(context).push<V2MejaItem>(
      V2MejaFormPage.route(
        takenCodes: takenCodes,
        onSubmit: (meja) => ref
            .read(connectedTableProvider.notifier)
            .createTable(
              code: meja.kode,
              holeCount: meja.jumlahLubang,
              notes: meja.keterangan,
            ),
      ),
    );
    if (result == null || !context.mounted) return;
    _pesan(context, 'Meja ditambahkan.');
  }
}

void _pesan(BuildContext context, String pesan) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(pesan)));
}

/// Detail meja yang mengubah status/ukuran dan menambah tanaman ke backend.
///
/// Dibuka lewat [tableId] (pintu masuk bersama, BUG-39) supaya isinya selalu
/// dihitung ulang dari provider. [item] hanya gambar awal/pratinjau.
class V2MejaConnectedDetailPage extends ConsumerStatefulWidget {
  const V2MejaConnectedDetailPage({
    super.key,
    this.tableId,
    this.item,
    this.onOpenSemaian,
  }) : assert(
         tableId != null || item != null,
         'Butuh tableId (pintu masuk bersama) atau item (pratinjau).',
       );

  /// Identitas meja backend; bila diisi, Detail meja membaca ulang dari provider.
  final String? tableId;

  /// Data awal/pratinjau; null bila dibuka hanya dengan [tableId].
  final V2MejaItem? item;

  /// Kembali ke dashboard lalu membuka segmen Semaian. Null berarti tidak ada
  /// akses ke shell; tombol "Lihat semaian" lalu hanya menutup pemilih.
  final VoidCallback? onOpenSemaian;

  @override
  ConsumerState<V2MejaConnectedDetailPage> createState() =>
      _V2MejaConnectedDetailPageState();
}

class _V2MejaConnectedDetailPageState
    extends ConsumerState<V2MejaConnectedDetailPage> {
  late V2MejaItem _item = widget.item ?? _lokalDariId(widget.tableId!);

  /// Meja tanpa data provider sesaat (mis. belum termuat): kerangka kosong.
  static V2MejaItem _lokalDariId(String id) => V2MejaItem(
    id: id,
    kode: '',
    jumlahLubang: 0,
    terisi: 0,
    status: V2MejaStatus.tersedia,
  );

  String? get _id => widget.tableId ?? _item.id;

  List<InventoryRecord> get _inventaris =>
      ref.read(connectedInventoryProvider).activeRecords;

  V2MejaItem? _dariBackend() {
    final id = _id;
    if (id == null) return null;
    final record = ref
        .read(connectedTableProvider)
        .records
        .where((row) => row.id == id)
        .firstOrNull;
    if (record == null) return null;
    return v2MejaItemFromRecord(
      record,
      transfers: ref.read(v2AllTransfersProvider).valueOrNull ?? const [],
      sowings: ref.read(v2AllSowingsProvider).valueOrNull ?? const [],
      inventaris: _inventaris,
      damages: _damages(),
    );
  }

  /// Semua laporan kerusakan meja ini dari `damageProvider`.
  List<DamageRecord> _damages() {
    final id = _id;
    if (id == null) return const <DamageRecord>[];
    return ref
        .read(damageProvider(id))
        .reports
        .values
        .expand((rows) => rows)
        .toList();
  }

  /// Nama benih batch, dipakai subjudul catatan rusak (frame 6.24).
  String _varietasTransfer(String transferId) {
    final transfer = (ref.read(v2AllTransfersProvider).valueOrNull ?? const [])
        .where((item) => item.id == transferId)
        .firstOrNull;
    if (transfer == null) return 'Tanaman meja';
    return v2NamaVarietasTransfer(
          transfer,
          ref.read(v2AllSowingsProvider).valueOrNull ?? const [],
          _inventaris,
        ) ??
        'Tanaman meja';
  }

  /// Meja yang ditampilkan, dengan daftar rusak terbaru dari backend.
  V2MejaItem _denganRusak(V2MejaItem item) {
    final rusak = _damages()
        .map(
          (damage) => v2KerusakanDariDamage(
            damage,
            varietas: _varietasTransfer(damage.transferId),
            meja: item.kode,
          ),
        )
        .toList();
    return item.copyWith(rusak: rusak);
  }

  Future<void> _ubahStatus(V2MejaStatus status) async {
    final id = _id;
    if (id == null) throw StateError('Meja belum tersimpan di server.');
    await ref
        .read(connectedTableProvider.notifier)
        .updateTable(
          id,
          status: switch (status) {
            V2MejaStatus.tersedia => 'tersedia',
            V2MejaStatus.penuh => 'penuh',
            V2MejaStatus.perawatan => 'pemeliharaan',
          },
        );
    _segarkan();
  }

  Future<void> _ubahMeja(V2MejaItem meja) async {
    final id = _id;
    if (id == null) throw StateError('Meja belum tersimpan di server.');
    await ref
        .read(connectedTableProvider.notifier)
        .updateTable(
          id,
          code: meja.kode,
          holeCount: meja.jumlahLubang,
          notes: meja.keterangan,
        );
    _segarkan();
  }

  Future<V2MejaItem?> _tambahTanaman() async {
    final id = _id;
    if (id == null) throw StateError('Meja belum tersimpan di server.');
    // Langkah 1: pilih semaian siap pindah. Kesiapan dihitung sama seperti
    // daftar semaian (HSS ≥ 15 dari tanggal semai), bukan menebak dari kolom
    // server yang bisa kosong (BUG-40).
    //
    // Tunggu daftar semaian benar-benar termuat: `valueOrNull` bernilai null
    // selama loading sehingga pemilih sempat tampil "Belum ada yang siap"
    // padahal semaian siap pindah ada (BUG-FE tambah tanaman).
    List<SowingRecord> rows;
    try {
      rows = await ref.read(v2AllSowingsProvider.future);
    } catch (error) {
      if (!mounted) return null;
      _pesan(context, serviceError(error));
      return null;
    }
    if (!mounted) return null;
    final siap = rows
        .map((row) => v2SemaianItemFromRecord(row, inventaris: _inventaris))
        .where((item) => item.siapPindah)
        .toList();
    final navigator = Navigator.of(context);
    final pilihan = await navigator.push<V2SemaianItem>(
      MaterialPageRoute<V2SemaianItem>(
        builder: (_) => V2PilihSemaianPage(
          items: siap,
          // "Lihat semaian" harus kembali ke dashboard lalu membuka segmen
          // Semaian, bukan menumpuk halaman baru di atas shell (BUG-FE).
          onLihatSemaian: widget.onOpenSemaian == null
              ? null
              : () {
                  navigator.popUntil((route) => route.isFirst);
                  widget.onOpenSemaian!();
                },
        ),
      ),
    );
    if (!mounted || pilihan == null) return null;

    // Langkah 2: buka form "Pindah ke meja" dengan default sesuai konteks
    // (D-25): meja ini terpilih, jumlah = min(sisa bibit, kapasitas meja).
    final meja = _daftarMejaPindah();
    if (meja.isEmpty) {
      meja.add(
        V2SemaianMeja(
          nama: _item.nama,
          lubangKosong: _item.kosong,
          tableId: id,
        ),
      );
    }
    final index = meja.indexWhere((item) => item.tableId == id);
    final sisa = pilihan.sisaBenih ?? pilihan.jumlahBenih;
    final jumlah = sisa < _kosongMeja(id) ? sisa : _kosongMeja(id);
    final hasil = await Navigator.of(context).push<V2SemaianPindah>(
      MaterialPageRoute<V2SemaianPindah>(
        builder: (_) => V2PindahMejaFormPage(
          item: pilihan,
          mejaAwal: index < 0 ? 0 : index,
          jumlahAwal: jumlah,
          daftarMeja: meja,
          initialDate: jakartaToday(),
          showResultPage: false,
          onPindahkan: (pindah) => _kirimPindahKe(id, pilihan.id, pindah),
        ),
      ),
    );
    if (!mounted || hasil == null) return null;
    final terbaru = _dariBackend() ?? _item.copyWith();
    setState(() => _item = terbaru);
    _pesan(context, 'Tanaman ditambahkan.');
    return terbaru;
  }

  /// Daftar meja untuk form "Pindah ke meja" dari data backend.
  List<V2SemaianMeja> _daftarMejaPindah() {
    return ref
        .read(connectedTableProvider)
        .records
        .map(
          (table) => V2SemaianMeja(
            nama: table.displayName,
            lubangKosong: table.availableCapacity,
            penuh: table.isFull,
            perawatan: table.isMaintenance,
            tableId: table.id,
          ),
        )
        .toList();
  }

  /// Lubang kosong meja dari data backend; jatuh ke salinan lokal bila belum ada.
  int _kosongMeja(String tableId) {
    final record = ref
        .read(connectedTableProvider)
        .records
        .where((row) => row.id == tableId)
        .firstOrNull;
    return record?.availableCapacity ?? _item.kosong;
  }

  /// Simpan satu pemindahan dan segarkan meja/pemindahan/penyemaian (BUG-34).
  Future<void> _kirimPindahKe(
    String tableId,
    String sowingId,
    V2SemaianPindah pindah,
  ) async {
    await ref
        .read(nurseryRepositoryProvider)
        .transferSowing(
          idempotencyKey: generateUuidV4(),
          sowingId: sowingId,
          tableId: tableId,
          transferDate: apiDate(pindah.tanggal),
          plantCount: pindah.jumlah,
        );
    await v2SegarkanSetelahTulis(ref, tableIds: {tableId});
  }

  /// Simpan catatan tanaman lewat `PATCH /api/v1/pemindahan/:id` (frame 6.22).
  Future<void> _ubahCatatanTanaman(
    V2TanamanItem tanaman,
    String? catatan,
  ) async {
    final id = _item.id;
    final transferId = tanaman.transferId;
    if (id == null || transferId == null) {
      throw StateError('Batch tanaman belum tersimpan di server.');
    }
    final result = await ref
        .read(damageProvider(id).notifier)
        .updateTransfer(transferId, note: catatan);
    if (result == DamageSubmitResult.busy) {
      throw StateError('Catatan sedang disimpan.');
    }
    if (result == DamageSubmitResult.failed) {
      throw StateError(
        ref.read(damageProvider(id)).error ?? 'Catatan gagal disimpan.',
      );
    }
    ref.invalidate(v2AllTransfersProvider);
    await ref.read(v2AllTransfersProvider.future);
    _segarkan();
  }

  /// Catat kerusakan baru lewat `POST /api/v1/kerusakan` (frame 6.25–6.27).
  Future<V2KerusakanItem> _catatRusak(V2KerusakanItem draft) async {
    final id = _item.id;
    final transferId = draft.transferId;
    if (id == null || transferId == null) {
      throw StateError('Batch tanaman tidak dikenali.');
    }
    final sebelum = _idKerusakan(id);
    final result = await ref
        .read(damageProvider(id).notifier)
        .submit(
          DamageDraft(
            transferId: transferId,
            date: apiDate(draft.tanggal),
            plantCount: draft.jumlah,
            category: draft.jenis,
            note: draft.keterangan,
          ),
        );
    await _selesaiRusak(id, result);
    return _cariRusak(id, _idKerusakan(id).difference(sebelum)) ?? draft;
  }

  /// Ubah laporan kerusakan lewat `PATCH /api/v1/kerusakan/:id` (frame 6.28).
  Future<V2KerusakanItem> _ubahRusak(V2KerusakanItem draft) async {
    final id = _item.id;
    final damageId = draft.id;
    if (id == null || damageId == null) {
      throw StateError('Laporan kerusakan tidak dikenali.');
    }
    final result = await ref
        .read(damageProvider(id).notifier)
        .updateDamage(
          damageId,
          date: apiDate(draft.tanggal),
          plantCount: draft.jumlah,
          category: draft.jenis,
          note: draft.keterangan,
        );
    await _selesaiRusak(id, result);
    return _cariRusak(id, {damageId}) ?? draft;
  }

  Future<void> _selesaiRusak(String tableId, DamageSubmitResult result) async {
    if (result == DamageSubmitResult.busy) {
      throw StateError('Kerusakan sedang disimpan.');
    }
    if (result == DamageSubmitResult.failed) {
      throw StateError(
        ref.read(damageProvider(tableId)).error ??
            'Laporan kerusakan gagal disimpan.',
      );
    }
    ref.invalidate(v2AllTransfersProvider);
    await ref.read(v2AllTransfersProvider.future);
    await ref.read(connectedTableProvider.notifier).refreshTable(tableId);
    _segarkan();
  }

  Set<String> _idKerusakan(String tableId) => ref
      .read(damageProvider(tableId))
      .reports
      .values
      .expand((rows) => rows)
      .map((row) => row.id)
      .toSet();

  /// Cari laporan yang baru disimpan berdasarkan sekumpulan id.
  V2KerusakanItem? _cariRusak(String tableId, Set<String> ids) {
    if (ids.isEmpty) return null;
    for (final row
        in ref
            .read(damageProvider(tableId))
            .reports
            .values
            .expand((rows) => rows)) {
      if (!ids.contains(row.id)) continue;
      return v2KerusakanDariDamage(
        row,
        varietas: _varietasTransfer(row.transferId),
        meja: _item.kode,
      );
    }
    return null;
  }

  void _segarkan() {
    final terbaru = _dariBackend();
    if (terbaru != null && mounted) setState(() => _item = terbaru);
  }

  @override
  Widget build(BuildContext context) {
    final id = _id;
    if (id != null) ref.watch(damageProvider(id));
    // Satu pintu masuk bersama (BUG-39): saat dibuka lewat id, Detail meja
    // selalu dihitung ulang dari provider (kapasitas, tanaman, kerusakan)
    // supaya tidak menampilkan data basi/kosong dari jalur halaman sukses.
    if (widget.tableId != null) {
      ref.watch(connectedTableProvider.select((state) => state.records));
      ref.watch(v2AllTransfersProvider);
      ref.watch(v2AllSowingsProvider);
      ref.watch(connectedInventoryProvider);
      final terbaru = _dariBackend();
      if (terbaru != null) _item = terbaru;
    }
    return V2MejaDetailPage(
      item: _denganRusak(_item),
      onUbahStatus: _ubahStatus,
      onUbahMeja: _ubahMeja,
      onTambahTanaman: _tambahTanaman,
      onUbahCatatanTanaman: _ubahCatatanTanaman,
      onCatatRusak: _catatRusak,
      onUbahRusak: _ubahRusak,
    );
  }
}
