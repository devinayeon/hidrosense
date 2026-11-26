import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/business_date.dart';
import '../../../core/uuid.dart';
import '../../../data/models/inventory_record.dart';
import '../../../data/models/nursery_record.dart';
import '../../../viewmodels/connected_inventory_viewmodel.dart';
import '../../../viewmodels/connected_nursery_viewmodel.dart';
import '../../../viewmodels/connected_table_viewmodel.dart';
import '../../../viewmodels/sowing_draft.dart';
import '../components/v2_semaian_data.dart';
import '../pages/v2_pindah_meja_page.dart';
import '../pages/v2_semaian_detail_page.dart';
import '../pages/v2_semaian_edit_page.dart';
import '../pages/v2_semaian_form_page.dart';
import '../pages/v2_semaian_list_page.dart';
import 'v2_meja_connected.dart';

/// `Benih Selada Romaine` → `Romaine`; nama benih backend lebih panjang dari
/// label yang dipakai desain.
String v2NamaBenih(String nama) {
  var hasil = nama.trim();
  for (final awalan in ['Benih ', 'Selada ']) {
    if (hasil.toLowerCase().startsWith(awalan.toLowerCase())) {
      hasil = hasil.substring(awalan.length);
    }
  }
  return hasil.isEmpty ? nama : hasil;
}

int _jumlahBahan(String? amount) {
  final value = double.tryParse(amount ?? '') ?? 0;
  return value <= 0 ? 1 : value.round();
}

/// Nama bahan dari inventaris; `Bahan` bila barisnya tak lagi ada di daftar.
String _namaBahan(List<InventoryRecord> inventaris, String inventoryId) {
  final item = inventaris
      .where((row) => row.id == inventoryId)
      .firstOrNull;
  return item == null ? 'Bahan' : v2NamaBenih(item.name);
}

/// Pemetaan satu batch penyemaian backend ke model page 05.
V2SemaianItem v2SemaianItemFromRecord(
  SowingRecord record, {
  List<InventoryRecord> inventaris = const <InventoryRecord>[],
}) {
  final material = record.materials.firstOrNull;
  final benih = material == null
      ? null
      : inventaris.where((item) => item.id == material.inventoryId).firstOrNull;
  final pindah = record.seedCount - record.remainingSeedCount;
  // Semua baris bahan ikut ditampilkan (BUG-44): kartu detail tidak boleh
  // hanya menyebut bahan pertama.
  final bahanList = <V2SemaianBahanPakai>[
    for (final line in record.materials)
      V2SemaianBahanPakai(
        nama: _namaBahan(inventaris, line.inventoryId),
        jumlah: _jumlahBahan(line.amount),
        satuan: line.unit,
        inventoryId: line.inventoryId,
      ),
  ];
  return V2SemaianItem(
    id: record.id,
    nama: benih == null ? 'Semaian' : v2NamaBenih(benih.name),
    tanggalSemai: DateTime.tryParse(record.sowingDate) ?? jakartaToday(),
    jumlahBenih: record.seedCount,
    selesai: record.status == 'selesai',
    jumlahBahan: _jumlahBahan(material?.amount),
    sisaBenih: pindah > 0 ? record.remainingSeedCount : null,
    jumlahPindah: pindah > 0 ? pindah : null,
    keterangan: record.note,
    hssDariServer: record.ageDays,
    bahanInventoryId: material?.inventoryId,
    bahanAmount: material?.amount,
    bahanUnit: material?.unit,
    bahanList: bahanList.isEmpty ? null : List.unmodifiable(bahanList),
  );
}

List<V2SemaianBahan> v2BahanSemaianDariInventaris(
  List<InventoryRecord> inventaris,
) {
  return inventaris
      .where((item) => item.active && v2JenisBenih(item))
      .map(
        (item) => V2SemaianBahan(
          nama: item.name,
          stok: (double.tryParse(item.balance) ?? 0).floor(),
          satuan: item.unit,
          inventoryId: item.id,
        ),
      )
      .toList();
}

/// Kategori benih dikenali lewat nama jenis; inventaris tidak menyimpan enum.
bool v2JenisBenih(InventoryRecord item) =>
    item.category.toLowerCase().contains('benih');

/// Isi tab "Tanam" segmen Semaian dengan data backend.
class V2SemaianConnectedTab extends ConsumerWidget {
  const V2SemaianConnectedTab({
    super.key,
    this.initialStatusIndex = 0,
    this.onSegmentChanged,
  });

  final int initialStatusIndex;
  final ValueChanged<int>? onSegmentChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(connectedNurseryProvider);
    final inventaris = ref.watch(
      connectedInventoryProvider.select((value) => value.activeRecords),
    );
    final items = state.records
        .map(
          (record) => v2SemaianItemFromRecord(record, inventaris: inventaris),
        )
        .toList();
    final viewState = switch (state) {
      ConnectedNurseryState(loading: true) when items.isEmpty =>
        V2SemaianState.loading,
      ConnectedNurseryState(error: _?) when items.isEmpty =>
        V2SemaianState.error,
      _ => V2SemaianState.ready,
    };
    return V2SemaianTabView(
      items: items,
      state: viewState,
      initialStatusIndex: initialStatusIndex,
      onSegmentChanged: onSegmentChanged,
      onRetry: () => ref.read(connectedNurseryProvider.notifier).refresh(),
      onAdd: () => _tambah(context, ref),
      onTapItem: (item) => _bukaDetail(context, ref, item),
    );
  }

  Future<void> _tambah(BuildContext context, WidgetRef ref) =>
      v2TambahSemaian(context, ref);

  Future<void> _bukaDetail(
    BuildContext context,
    WidgetRef ref,
    V2SemaianItem item,
  ) {
    return v2BukaDetailSemaian(context, item);
  }
}

/// Tambah semaian dari inventaris nyata (form 5.7). Dipakai tab Semaian dan
/// daftar semaian tersambung supaya keduanya satu perilaku.
Future<void> v2TambahSemaian(BuildContext context, WidgetRef ref) async {
  final inventaris = ref.read(connectedInventoryProvider).activeRecords;
  final bahan = v2BahanSemaianDariInventaris(inventaris);
  if (bahan.isEmpty) {
    _pesan(context, 'Belum ada benih aktif di inventaris.');
    return;
  }
  final result = await Navigator.of(context).push<V2SemaianItem>(
    V2SemaianFormPage.route(
      bahanList: bahan,
      initialDate: jakartaToday(),
      onSubmit: (hasil) => _kirimSemaianBaru(ref, hasil),
    ),
  );
  if (result == null || !context.mounted) return;
  _pesan(context, 'Semaian ditambahkan.');
}

/// Kirim semaian baru ke backend. Dipanggil dari pop-up konfirmasi di form
/// supaya daftar tidak kembali lebih dulu sebelum proses selesai (Sesi 9).
Future<void> _kirimSemaianBaru(WidgetRef ref, V2SemaianItem hasil) async {
  final pakai = hasil.bahanList;
  final inventoryId = hasil.bahanInventoryId;
  if ((pakai == null || pakai.isEmpty) && inventoryId == null) {
    throw StateError('Pilih bahan dari inventaris.');
  }
  await ref
      .read(connectedNurseryProvider.notifier)
      .saveSowing(
        SowingDraft(
          date: apiDate(hasil.tanggalSemai),
          seedCount: hasil.jumlahBenih,
          note: hasil.keterangan ?? '',
          inventoryId: inventoryId,
          amount: hasil.bahanAmount ?? '1',
          unit: hasil.bahanUnit ?? 'pak',
          materials: [
            for (final bahan in pakai ?? const <V2SemaianBahanPakai>[])
              if (bahan.inventoryId != null)
                SowingMaterialDraft(
                  inventoryId: bahan.inventoryId!,
                  amount: '${bahan.jumlah}',
                  unit: bahan.satuan,
                ),
          ],
        ),
      );
}

/// Buka detail semaian tersambung; hasilnya menggantikan baris pemanggil.
Future<V2SemaianItem?> v2BukaDetailSemaian(
  BuildContext context,
  V2SemaianItem item,
) {
  return Navigator.of(context).push<V2SemaianItem>(
    MaterialPageRoute<V2SemaianItem>(
      builder: (_) => V2SemaianConnectedDetailPage(item: item),
    ),
  );
}

/// Daftar semaian tersambung (frame 5.1) untuk dibuka dari alur lain lewat
/// pintu yang sama — mis. tombol "Lihat semaian" di pemilih semaian (BUG-41).
class V2SemaianConnectedListPage extends ConsumerWidget {
  const V2SemaianConnectedListPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
    builder: (_) => const V2SemaianConnectedListPage(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(connectedNurseryProvider);
    final inventaris = ref.watch(
      connectedInventoryProvider.select((value) => value.activeRecords),
    );
    final items = state.records
        .map(
          (record) => v2SemaianItemFromRecord(record, inventaris: inventaris),
        )
        .toList();
    final viewState = switch (state) {
      ConnectedNurseryState(loading: true) when items.isEmpty =>
        V2SemaianState.loading,
      ConnectedNurseryState(error: _?) when items.isEmpty =>
        V2SemaianState.error,
      _ => V2SemaianState.ready,
    };
    return V2SemaianListPage(
      items: items,
      state: viewState,
      onAdd: () => v2TambahSemaian(context, ref),
      onTapItem: (item) => v2BukaDetailSemaian(context, item),
    );
  }
}

void _pesan(BuildContext context, String pesan) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(pesan)));
}

/// Detail semaian dengan ubah dan pindah ke meja yang menulis ke backend.
class V2SemaianConnectedDetailPage extends ConsumerStatefulWidget {
  const V2SemaianConnectedDetailPage({super.key, required this.item});

  final V2SemaianItem item;

  @override
  ConsumerState<V2SemaianConnectedDetailPage> createState() =>
      _V2SemaianConnectedDetailPageState();
}

class _V2SemaianConnectedDetailPageState
    extends ConsumerState<V2SemaianConnectedDetailPage> {
  late V2SemaianItem _item = widget.item;
  String? _toast;

  SowingRecord? _record() => ref
      .read(connectedNurseryProvider)
      .records
      .where((record) => record.id == _item.id)
      .firstOrNull;

  void _segarkan(String toast) {
    final record = _record();
    if (record == null) return;
    final inventaris = ref.read(connectedInventoryProvider).activeRecords;
    setState(() {
      _item = v2SemaianItemFromRecord(record, inventaris: inventaris);
      _toast = toast;
    });
  }

  Future<void> _ubah() async {
    final updated = await Navigator.of(context).push<V2SemaianItem>(
      MaterialPageRoute<V2SemaianItem>(
        builder: (_) => V2SemaianEditPage(
          item: _item,
          onSubmit: (hasil) async {
            await ref
                .read(connectedNurseryProvider.notifier)
                .saveSowing(
                  SowingDraft(
                    id: _item.id,
                    date: apiDate(_item.tanggalSemai),
                    seedCount: hasil.jumlahBenih,
                    note: hasil.keterangan ?? '',
                    // Tandai selesai hanya bila status berubah; tidak ada jalan
                    // balik karena form ubah disembunyikan untuk semaian selesai.
                    status: hasil.selesai && !_item.selesai ? 'selesai' : null,
                  ),
                );
          },
        ),
      ),
    );
    if (!mounted || updated == null) return;
    _segarkan('Perubahan tersimpan');
  }

  Future<void> _pindah() async {
    var sisa = _item.sisaBenih ?? _item.jumlahBenih;
    // Ulang selama pengguna memilih "Pindahkan sisa": daftar meja dibangun
    // ulang tiap putaran dari data segar sehingga lubang kosong ikut
    // berkurang sesuai yang baru dipindah (BUG-34a).
    while (true) {
      final meja = ref
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
      if (meja.isEmpty) {
        _pesan(context, 'Belum ada meja tanam.');
        return;
      }
      final hasil = await Navigator.of(context).push<V2SemaianPindah>(
        MaterialPageRoute<V2SemaianPindah>(
          builder: (_) => V2PindahMejaFormPage(
            item: _item,
            daftarMeja: meja,
            initialDate: jakartaToday(),
            jumlahAwal: sisa,
            onPindahkan: _kirimPindah,
          ),
        ),
      );
      if (!mounted || hasil == null) return;
      if (hasil.aksi == V2PindahMejaAksi.keDaftarSemaian) {
        // Tombol "Ke daftar semaian" menutup detail, kembali ke daftar
        // (BUG-28).
        Navigator.of(context).maybePop();
        return;
      }
      // Segarkan semaian ini dari data yang baru dimuat `_kirimPindah`.
      _segarkan('Bibit dipindah');
      if (hasil.aksi == V2PindahMejaAksi.lihatMeja && hasil.tableId != null) {
        await _bukaMeja(ref, hasil.tableId!);
        return;
      }
      if (hasil.aksi == V2PindahMejaAksi.pindahkanSisa) {
        sisa = _item.sisaBenih ?? _item.jumlahBenih;
        if (sisa <= 0) return;
        continue;
      }
      return;
    }
  }

  /// Buka detail meja tujuan setelah pindah (tombol "Lihat meja", BUG-28).
  ///
  /// Memuat pemindahan & penyemaian terbaru dulu supaya Detail meja tidak
  /// memakai objek lama (BUG-34b): tanaman terisi dan semaian siap pindah
  /// tampil benar.
  Future<void> _bukaMeja(WidgetRef ref, String tableId) async {
    final record = ref
        .read(connectedTableProvider)
        .records
        .where((row) => row.id == tableId)
        .firstOrNull;
    if (record == null) return;
    final transfers = await ref.read(v2AllTransfersProvider.future);
    final sowings = await ref.read(v2AllSowingsProvider.future);
    if (!mounted) return;
    final item = v2MejaItemFromRecord(
      record,
      transfers: transfers,
      sowings: sowings,
      inventaris: ref.read(connectedInventoryProvider).activeRecords,
    );
    await bukaDetailMeja(Navigator.of(context), tableId, item: item);
  }

  Future<void> _kirimPindah(V2SemaianPindah pindah) async {
    final tableId = pindah.tableId;
    if (tableId == null) {
      throw StateError('Meja tujuan tidak dikenali.');
    }
    await ref
        .read(connectedNurseryProvider.notifier)
        .submitTransfer(
          SeedlingTransferCommand((
            idempotencyKey: generateUuidV4(),
            sowingId: _item.id,
            tableId: tableId,
            transferDate: apiDate(pindah.tanggal),
            plantCount: pindah.jumlah,
            note: '',
          )),
        );
    await ref.read(connectedNurseryProvider.notifier).refresh();
    // Meja + pemindahan + penyemaian dimuat ulang supaya form sisa dan Detail
    // meja berikutnya memakai data terbaru (BUG-34).
    await v2SegarkanSetelahTulis(ref, tableIds: {tableId});
  }

  @override
  Widget build(BuildContext context) {
    return V2SemaianDetailPage(
      item: _item,
      toast: _toast,
      onEdit: _ubah,
      onMove: _pindah,
    );
  }
}
