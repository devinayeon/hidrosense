import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/business_date.dart';
import '../../../core/formatting.dart';
import '../../../data/models/inventory_record.dart';
import '../../../data/models/jenis_inventaris_record.dart';
import '../../../data/models/stock_movement_record.dart';
import '../../../data/repositories/inventory_repository.dart';
import '../../../viewmodels/connected_inventory_viewmodel.dart';
import '../../../viewmodels/inventory_draft.dart';
import '../../../viewmodels/session_viewmodel.dart';
import '../components/v2_inventaris_catat_sheet.dart';
import '../components/v2_inventaris_data.dart';
import '../pages/v2_inventaris_detail_page.dart';
import '../pages/v2_inventaris_form_page.dart';
import '../pages/v2_inventaris_list_page.dart';
import '../widgets/v2_dialog.dart';

/// Pemetaan record inventaris backend ke model desain page 04.
///
/// Jenis barang backend tidak sama persis dengan empat chip desain: seed
/// memakai nama `Obat & Pestisida` dan `Perlengkapan`. Pencocokan dibuat longgar
/// supaya barang dari kategori mana pun tetap jatuh ke chip yang masuk akal.
V2JenisBarang v2JenisFromCategory(String category) {
  final lower = category.toLowerCase();
  if (lower.contains('obat') || lower.contains('pestisida')) {
    return V2JenisBarang.obat;
  }
  if (lower.contains('media') ||
      lower.contains('perlengkapan') ||
      lower.contains('rockwool')) {
    return V2JenisBarang.media;
  }
  if (lower.contains('nutrisi') || lower.contains('pupuk')) {
    return V2JenisBarang.nutrisi;
  }
  return V2JenisBarang.benih;
}

V2InventarisItem v2InventarisItemFromRecord(
  InventoryRecord record, {
  List<V2InventarisRiwayat> riwayat = const <V2InventarisRiwayat>[],
}) {
  final jumlah = double.tryParse(record.balance) ?? 0;
  final minimum = record.minimum == null
      ? null
      : double.tryParse(record.minimum!);
  // Barang bisa tertaut ke katalog bawaan (`id_katalog`) atau master pengguna
  // (`id_obat`); form butuh tahu sumbernya supaya mengirim kolom yang tepat.
  final katalog = record.katalogId != null;
  return V2InventarisItem(
    id: record.id,
    nama: record.name,
    jenis: v2JenisFromCategory(record.category),
    jumlah: jumlah,
    satuan: record.unit,
    status: statusStok(jumlah, minimum),
    arsip: !record.active,
    minimum: minimum,
    riwayat: riwayat,
    medicineId: katalog ? record.katalogId : record.medicineId,
    medicineName: katalog ? record.katalogName : record.medicineName,
    medicineKatalog: katalog,
  );
}

/// Riwayat keluar-masuk satu barang untuk kartu detail (frame 4.17–4.20).
final inventoryHistoryProvider = FutureProvider.autoDispose
    .family<List<V2InventarisRiwayat>, String>((ref, inventoryId) async {
      final user = ref.watch(sessionProvider.select((state) => state.user));
      if (user == null) return const <V2InventarisRiwayat>[];
      final repository = InventoryRepository(
        ref.watch(apiClientProvider),
        ref.watch(inventoryCacheProvider),
        userId: user.id,
      );
      final rows = await repository.fetchStockHistory(
        inventoryId: inventoryId,
        limit: 20,
      );
      return rows.map(_riwayatFromMovement).toList();
    });

V2InventarisRiwayat _riwayatFromMovement(StockMovementRecord movement) {
  final line = movement.details.firstOrNull;
  final jumlah = line?.amount ?? '';
  final satuan = line?.unit ?? '';
  final aksi = movement.direction == 'masuk' ? 'Masuk' : 'Pakai';
  final hariIni = jakartaToday();
  final tanggal = movement.date;
  final labelTanggal =
      tanggal.year == hariIni.year &&
          tanggal.month == hariIni.month &&
          tanggal.day == hariIni.day
      ? 'Hari ini'
      : formatTanggalIndo(tanggal, singkat: true);
  return V2InventarisRiwayat(
    '$aksi ${formatAngka(double.tryParse(jumlah) ?? 0)} $satuan'.trim(),
    labelTanggal,
  );
}

/// Pesan saat server tidak punya satu pun jenis inventaris aktif. Tanpa
/// kategori, barang tidak bisa dibuat sama sekali (kontrak mewajibkan
/// `id_jenis_inventaris`), jadi form tidak perlu dibuka lebih dulu.
const v2KategoriKosongPesan =
    'Kategori barang belum tersedia di server. Minta admin menambahkan jenis '
    'barang terlebih dahulu.';

const _kategoriGagalPesan =
    'Kategori barang gagal dimuat. Periksa koneksi lalu coba lagi.';

bool _samaKata(String nama, List<String> kata) {
  final lower = nama.toLowerCase();
  return kata.any(lower.contains);
}

/// Kategori yang benar-benar cocok dengan [jenis] berdasarkan kata kunci nama
/// jenis. Null bila tidak ada yang cocok (tidak menebak).
JenisInventarisRecord? _kategoriCocok(
  List<JenisInventarisRecord> kategori,
  V2JenisBarang jenis,
) {
  final aktif = kategori.where((item) => item.active).toList();
  if (aktif.isEmpty) return null;
  return switch (jenis) {
    V2JenisBarang.benih =>
      aktif.where((item) => _samaKata(item.name, ['benih', 'bibit'])).firstOrNull,
    V2JenisBarang.nutrisi =>
      aktif
          .where((item) => _samaKata(item.name, ['nutrisi', 'pupuk']))
          .firstOrNull,
    V2JenisBarang.media =>
      aktif
          .where((item) => _samaKata(item.name, ['media', 'perlengkapan']))
          .firstOrNull,
    V2JenisBarang.obat =>
      aktif
          .where((item) => _samaKata(item.name, ['obat', 'pestisida']))
          .firstOrNull,
  };
}

/// Kategori untuk [jenis] saat menambah barang: yang cocok, atau kategori aktif
/// pertama sebagai upaya terakhir supaya penambahan tetap bisa jalan.
JenisInventarisRecord? _kategoriUntuk(
  List<JenisInventarisRecord> kategori,
  V2JenisBarang jenis,
) {
  final aktif = kategori.where((item) => item.active).toList();
  if (aktif.isEmpty) return null;
  return _kategoriCocok(kategori, jenis) ?? aktif.first;
}

/// Kategori aktif dari cache provider bila sudah dimuat; selain itu menunggu
/// permintaan. Null berarti permintaan gagal (bukan daftar kosong), supaya
/// pesan "belum tersedia" tidak dipakai untuk gangguan jaringan.
Future<List<JenisInventarisRecord>?> _bacaKategori(WidgetRef ref) async {
  final cached = ref.read(inventoryCategoriesProvider).valueOrNull;
  if (cached != null) return cached;
  try {
    return await ref.read(inventoryCategoriesProvider.future);
  } catch (_) {
    ref.invalidate(inventoryCategoriesProvider);
    return null;
  }
}

String _angkaDraft(double value) => formatAngka(value);

/// Isi tab "Stok" dengan data backend; pengganti fixture saat sesi aktif.
class V2InventarisConnectedTab extends ConsumerWidget {
  const V2InventarisConnectedTab({
    super.key,
    this.initialJenis,
    this.initialStatusIndex = 0,
    this.openFilterOnStart = false,
  });

  final V2JenisBarang? initialJenis;
  final int initialStatusIndex;
  final bool openFilterOnStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hangatkan daftar pendukung sejak tab dibuka: tombol Tambah/Ubah tidak
    // perlu menunggu permintaan jaringan sebelum form tampil (K-07).
    ref.watch(inventoryCategoriesProvider);
    ref.watch(obatKatalogProvider);
    final data = ref.watch(connectedInventoryProvider);
    final items = data.records
        .map((record) => v2InventarisItemFromRecord(record))
        .toList();
    final state = switch (data) {
      ConnectedInventoryState(isInitialLoading: true) =>
        V2InventarisState.loading,
      ConnectedInventoryState(error: _?) when items.isEmpty =>
        V2InventarisState.error,
      _ => V2InventarisState.ready,
    };
    return V2InventarisTabView(
      items: items,
      state: state,
      initialJenis: initialJenis,
      initialStatusIndex: initialStatusIndex,
      openFilterOnStart: openFilterOnStart,
      onRetry: () => ref.read(connectedInventoryProvider.notifier).refresh(),
      onAdd: () => _tambah(context, ref),
      onTapItem: (item) => _bukaDetail(context, ref, item),
    );
  }

  Future<void> _tambah(BuildContext context, WidgetRef ref) async {
    // Periksa prasyarat sebelum form dibuka. Tanpa kategori aktif, barang tidak
    // mungkin disimpan; lebih baik beri tahu sekarang daripada setelah isian
    // penuh (K-08).
    final kategori = await _bacaKategori(ref);
    if (!context.mounted) return;
    if (kategori == null) {
      _pesan(context, _kategoriGagalPesan);
      return;
    }
    if (kategori.every((item) => !item.active)) {
      _pesan(context, v2KategoriKosongPesan);
      return;
    }
    final obat = await _obatPilihan(ref);
    if (!context.mounted) return;
    final result = await Navigator.of(context).push<V2InventarisItem>(
      V2InventarisFormPage.route(
        obatPilihan: obat,
        onSubmit: (hasil) async {
          final pilihan = _kategoriUntuk(kategori, hasil.jenis);
          if (pilihan == null) throw StateError(v2KategoriKosongPesan);
          await ref
              .read(connectedInventoryProvider.notifier)
              .saveItem(
                InventoryDraft(
                  name: hasil.nama,
                  categoryId: pilihan.id,
                  unit: hasil.satuan,
                  minimum: hasil.minimum == null
                      ? ''
                      : _angkaDraft(hasil.minimum!),
                  initialStock: _angkaDraft(hasil.jumlah),
                  medicineId: hasil.medicineKatalog ? null : hasil.medicineId,
                  katalogId: hasil.medicineKatalog ? hasil.medicineId : null,
                ),
              );
        },
      ),
    );
    if (result == null || !context.mounted) return;
    _pesan(context, 'Barang ditambahkan.');
  }

  Future<void> _bukaDetail(
    BuildContext context,
    WidgetRef ref,
    V2InventarisItem item,
  ) async {
    final hasil = await Navigator.of(context).push<V2InventarisItem>(
      MaterialPageRoute<V2InventarisItem>(
        builder: (_) => V2InventarisConnectedDetailPage(item: item),
      ),
    );
    if (!context.mounted || hasil == null) return;
    // Barang arsip yang dipulihkan: beri tahu di daftar.
    if (item.arsip && !hasil.arsip) {
      _pesan(context, '${item.nama} diaktifkan kembali.');
    }
  }
}

void _pesan(BuildContext context, String pesan) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(pesan)));
}

/// Daftar obat untuk sheet "Pilih obat"; kosong bila layanan tidak tersedia
/// supaya penambahan barang jenis lain tetap jalan.
Future<List<V2ObatPilihan>> _obatPilihan(WidgetRef ref) async {
  final cached = ref.read(obatKatalogProvider).valueOrNull;
  if (cached != null) return v2ObatPilihanDariKatalog(cached);
  try {
    final katalog = await ref.read(obatKatalogProvider.future);
    return v2ObatPilihanDariKatalog(katalog);
  } catch (_) {
    return const <V2ObatPilihan>[];
  }
}

/// Detail barang yang membaca riwayat dan menulis aksi ke backend.
class V2InventarisConnectedDetailPage extends ConsumerStatefulWidget {
  const V2InventarisConnectedDetailPage({super.key, required this.item});

  final V2InventarisItem item;

  @override
  ConsumerState<V2InventarisConnectedDetailPage> createState() =>
      _V2InventarisConnectedDetailPageState();
}

class _V2InventarisConnectedDetailPageState
    extends ConsumerState<V2InventarisConnectedDetailPage> {
  late V2InventarisItem _item = widget.item;
  String? _toast;

  InventoryRecord? _record() => ref
      .read(connectedInventoryProvider)
      .records
      .where((record) => record.id == _item.id)
      .firstOrNull;

  Future<void> _catatStok() async {
    final hasil = await showV2CatatStokSheet(context, item: _item, jumlah: 2);
    if (!mounted || hasil == null) return;
    final record = _record();
    if (record == null) {
      _pesan(context, 'Barang belum termuat. Coba muat ulang daftar.');
      return;
    }
    try {
      final done = await showV2ActionDialog(
        context,
        title: 'Catat stok ${hasil.masuk ? 'masuk' : 'keluar'}?',
        body:
            '${_item.nama}: ${hasil.jumlah} ${_item.satuan} akan dicatat '
            '${hasil.masuk ? 'masuk' : 'keluar'}.',
        primaryLabel: 'Catat',
        onConfirm: () => ref
            .read(connectedInventoryProvider.notifier)
            .recordStock(
              item: record,
              masuk: hasil.masuk,
              jumlah: '${hasil.jumlah}',
              note: 'Dicatat dari halaman detail v2',
            ),
      );
      if (!mounted || !done) return;
      _segarkan('Stok dicatat');
    } catch (error) {
      if (!mounted) return;
      _pesan(context, serviceError(error));
    }
  }

  Future<void> _ubah() async {
    final obat = await _obatPilihan(ref);
    if (!mounted) return;
    final updated = await Navigator.of(context).push<V2InventarisItem>(
      V2InventarisFormPage.routeUbah(
        _item,
        obatPilihan: obat,
        onSubmit: (hasil) async {
          final record = _record();
          final kategori = await _bacaKategori(ref);
          // Jenis boleh diubah di form, jadi kategori tujuan dihitung dari jenis
          // baru. `record?.categoryId` selalu terisi sehingga dulu menahan
          // perubahan jenis; sekarang hanya dipakai sebagai cadangan bila
          // kategori belum termuat atau jenis baru tidak punya kategori cocok.
          final pilihan =
              (kategori == null
                  ? null
                  : _kategoriCocok(kategori, hasil.jenis)?.id) ??
              record?.categoryId;
          if (pilihan == null) throw StateError(v2KategoriKosongPesan);
          await ref
              .read(connectedInventoryProvider.notifier)
              .saveItem(
                InventoryDraft(
                  id: _item.id,
                  name: hasil.nama,
                  categoryId: pilihan,
                  unit: hasil.satuan,
                  minimum: hasil.minimum == null
                      ? ''
                      : _angkaDraft(hasil.minimum!),
                  initialStock: '',
                  medicineId: hasil.medicineKatalog ? null : hasil.medicineId,
                  katalogId: hasil.medicineKatalog ? hasil.medicineId : null,
                ),
              );
        },
      ),
    );
    if (!mounted || updated == null) return;
    _segarkan('Perubahan tersimpan');
  }

  Future<void> _arsipkan() async {
    try {
      final done = await showV2ActionDialog(
        context,
        type: V2DialogType.destructive,
        title: 'Arsipkan barang?',
        body:
            '${_item.nama} hilang dari daftar. Riwayat tetap bisa dilihat di '
            'Arsip.',
        primaryLabel: 'Arsipkan',
        onConfirm: () =>
            ref.read(connectedInventoryProvider.notifier).deactivateItem(_item.id),
      );
      if (!mounted || !done) return;
      Navigator.of(context).pop(_item.copyWith(arsip: true));
    } catch (error) {
      if (!mounted) return;
      _pesan(context, serviceError(error));
    }
  }

  /// Aktifkan kembali barang arsip; halaman menutup sambil membawa barang aktif
  /// supaya daftar menampilkannya lagi.
  Future<void> _aktifkan() async {
    try {
      final done = await showV2ActionDialog(
        context,
        title: 'Aktifkan kembali barang?',
        body: '${_item.nama} kembali muncul di daftar stok.',
        primaryLabel: 'Aktifkan',
        onConfirm: () => ref
            .read(connectedInventoryProvider.notifier)
            .activateItem(_item.id),
      );
      if (!mounted || !done) return;
      Navigator.of(context).pop(_item.copyWith(arsip: false));
    } catch (error) {
      if (!mounted) return;
      _pesan(context, serviceError(error));
    }
  }

  void _segarkan(String toast) {
    final record = _record();
    if (record != null) {
      final riwayat = ref.read(inventoryHistoryProvider(_item.id)).valueOrNull;
      setState(() {
        _item = v2InventarisItemFromRecord(
          record,
          riwayat: riwayat ?? _item.riwayat,
        );
        _toast = toast;
      });
    }
    ref.invalidate(inventoryHistoryProvider(_item.id));
  }

  @override
  Widget build(BuildContext context) {
    final riwayat = ref.watch(inventoryHistoryProvider(_item.id));
    final item = riwayat.maybeWhen(
      data: (rows) => _item.copyWith(riwayat: rows),
      orElse: () => _item,
    );
    return V2InventarisDetailPage(
      item: item,
      footerLabel: V2InventarisDetailPage.footerLabelFor(_item),
      showAksi: !_item.arsip,
      toast: _toast,
      onCatatStok: _catatStok,
      onUbah: _ubah,
      onArsipkan: _arsipkan,
      onAktifkan: _aktifkan,
    );
  }
}
