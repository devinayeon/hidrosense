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
    medicineId: record.medicineId,
    medicineName: record.medicineName,
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

JenisInventarisRecord? _kategoriUntuk(
  List<JenisInventarisRecord> kategori,
  V2JenisBarang jenis,
) {
  final aktif = kategori.where((item) => item.active).toList();
  if (aktif.isEmpty) return null;
  bool cocok(JenisInventarisRecord item, List<String> kata) {
    final nama = item.name.toLowerCase();
    return kata.any(nama.contains);
  }

  final pilihan = switch (jenis) {
    V2JenisBarang.benih => aktif
        .where((item) => cocok(item, ['benih', 'bibit']))
        .firstOrNull,
    V2JenisBarang.nutrisi => aktif
        .where((item) => cocok(item, ['nutrisi', 'pupuk']))
        .firstOrNull,
    V2JenisBarang.media => aktif
        .where((item) => cocok(item, ['media', 'perlengkapan']))
        .firstOrNull,
    V2JenisBarang.obat => aktif
        .where((item) => cocok(item, ['obat', 'pestisida']))
        .firstOrNull,
  };
  return pilihan ?? aktif.first;
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
    final data = ref.watch(connectedInventoryProvider);
    final items = data.records
        .map((record) => v2InventarisItemFromRecord(record))
        .toList();
    final state = switch (data) {
      ConnectedInventoryState(isInitialLoading: true) => V2InventarisState.loading,
      ConnectedInventoryState(error: _?) when items.isEmpty => V2InventarisState.error,
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
    final obat = await _obatPilihan(ref);
    if (!context.mounted) return;
    final result = await Navigator.of(context).push<V2InventarisItem>(
      V2InventarisFormPage.route(obatPilihan: obat),
    );
    if (result == null || !context.mounted) return;
    try {
      final kategori = await ref.read(inventoryCategoriesProvider.future);
      final pilihan = _kategoriUntuk(kategori, result.jenis);
      if (pilihan == null) {
        if (!context.mounted) return;
        _pesan(context, 'Kategori barang belum tersedia.');
        return;
      }
      await ref
          .read(connectedInventoryProvider.notifier)
          .saveItem(
            InventoryDraft(
              name: result.nama,
              categoryId: pilihan.id,
              unit: result.satuan,
              minimum: result.minimum == null
                  ? ''
                  : _angkaDraft(result.minimum!),
              initialStock: _angkaDraft(result.jumlah),
              medicineId: result.medicineId,
            ),
          );
      if (!context.mounted) return;
      _pesan(context, 'Barang ditambahkan.');
    } catch (error) {
      if (!context.mounted) return;
      _pesan(context, serviceError(error));
    }
  }

  Future<void> _bukaDetail(
    BuildContext context,
    WidgetRef ref,
    V2InventarisItem item,
  ) async {
    await Navigator.of(context).push<V2InventarisItem>(
      MaterialPageRoute<V2InventarisItem>(
        builder: (_) => V2InventarisConnectedDetailPage(item: item),
      ),
    );
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
  try {
    final obat = await ref.read(inventoryMedicinesProvider.future);
    return v2ObatPilihanDari(obat);
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
    final hasil = await showV2CatatStokSheet(
      context,
      item: _item,
      jumlah: 2,
    );
    if (!mounted || hasil == null) return;
    final record = _record();
    if (record == null) {
      _pesan(context, 'Barang belum termuat. Coba muat ulang daftar.');
      return;
    }
    try {
      await ref
          .read(connectedInventoryProvider.notifier)
          .recordStock(
            item: record,
            masuk: hasil.masuk,
            jumlah: '${hasil.jumlah}',
            note: 'Dicatat dari halaman detail v2',
          );
      if (!mounted) return;
      _segarkan('Stok dicatat');
    } catch (error) {
      if (!mounted) return;
      _pesan(context, serviceError(error));
    }
  }

  Future<void> _ubah() async {
    final obat = await _obatPilihan(ref);
    if (!mounted) return;
    final updated = await Navigator.of(
      context,
    ).push<V2InventarisItem>(
      V2InventarisFormPage.routeUbah(_item, obatPilihan: obat),
    );
    if (!mounted || updated == null) return;
    final record = _record();
    try {
      final kategori = await ref.read(inventoryCategoriesProvider.future);
      final pilihan = record?.categoryId ??
          _kategoriUntuk(kategori, updated.jenis)?.id;
      if (pilihan == null) {
        if (!mounted) return;
        _pesan(context, 'Kategori barang belum tersedia.');
        return;
      }
      await ref
          .read(connectedInventoryProvider.notifier)
          .saveItem(
            InventoryDraft(
              id: _item.id,
              name: updated.nama,
              categoryId: pilihan,
              unit: updated.satuan,
              minimum: updated.minimum == null
                  ? ''
                  : _angkaDraft(updated.minimum!),
              initialStock: '',
              medicineId: updated.medicineId,
            ),
          );
      if (!mounted) return;
      _segarkan('Perubahan tersimpan');
    } catch (error) {
      if (!mounted) return;
      _pesan(context, serviceError(error));
    }
  }

  Future<void> _arsipkan() async {
    final confirmed = await showV2Dialog(
      context,
      type: V2DialogType.destructive,
      title: 'Arsipkan barang?',
      body:
          '${_item.nama} hilang dari daftar. Riwayat tetap bisa dilihat di '
          'Arsip.',
      primaryLabel: 'Arsipkan',
      secondaryLabel: 'Batal',
    );
    if (!mounted || confirmed != true) return;
    try {
      await ref
          .read(connectedInventoryProvider.notifier)
          .deactivateItem(_item.id);
      if (!mounted) return;
      Navigator.of(context).pop(_item.copyWith(arsip: true));
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
    );
  }
}