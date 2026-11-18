import '../models/penjualan_model.dart';
import '../views/v2/components/v2_penjualan_data.dart';
import 'penjualan_mappers.dart';

/// Mengubah satu baris server menjadi model tampilan page 08.
///
/// Label panen memakai sisa stok batch setelah penjualan ini, sama seperti
/// yang tampil di sheet "Pilih panen" (frame 8.9).
V2Penjualan v2PenjualanFromItem(
  PenjualanItem item,
  List<BatchPanen> batches,
) {
  final line = item.details.length == 1 ? item.details.single : null;
  final kg = item.details.isEmpty
      ? parseKg(item.kuantitas)
      : item.details.fold<double>(0, (sum, row) => sum + row.jumlahKg);
  final harga = line?.hargaPerKg ?? (kg > 0 ? item.totalHarga / kg : 0);
  final panenId = item.batchPanenId;

  final tanggalPanen = line == null
      ? null
      : DateTime.tryParse(line.tanggalPanen);

  String panen;
  String panenAsal;
  if (line == null) {
    panen = '${item.details.length} panen';
    panenAsal = 'Dari ${item.details.length} panen';
  } else {
    final batch = panenId == null ? null : _firstBatch(batches, panenId);
    final tanggalBatch =
        (batch?.tanggalPanen == null
            ? null
            : DateTime.tryParse(batch!.tanggalPanen!)) ??
        tanggalPanen ??
        DateTime.now();
    panen = 'Panen ${formatTanggalPendek(tanggalBatch)}';
    if (batch != null) panen += ', sisa ${formatKg(batch.stokTersedia)}';
    panenAsal = 'Dari panen ${formatTanggalPendek(tanggalBatch)}';
  }

  return V2Penjualan(
    id: item.id,
    pembeli: item.pembeli,
    tanggal: item.tanggalTransaksi ?? DateTime.now(),
    jumlahKg: kg,
    hargaPerKg: harga,
    pembayaran: item.isLunas
        ? V2PenjualanBayar.lunas
        : V2PenjualanBayar.belumLunas,
    panen: panen,
    panenAsal: panenAsal,
    panenId: panenId,
    tanggalPanen: tanggalPanen,
    version: item.version,
  );
}

BatchPanen? _firstBatch(List<BatchPanen> batches, String id) {
  for (final batch in batches) {
    if (batch.id == id) return batch;
  }
  return null;
}

/// Pilihan sheet "Pilih panen" dari batch panen server.
///
/// Semua batch ikut tampil; yang sisanya 0 kg dinonaktifkan seperti frame 8.9.
/// Saat mengubah satu penjualan, batch milik baris itu mendapat kembali berat
/// yang akan dilepas, sama seperti formulir v1 (`saleBatchesForForm`).
List<V2PenjualanPanen> v2PanenOptions(
  List<BatchPanen> batches, {
  PenjualanItem? editing,
}) {
  final rows = editing == null
      ? batches
      : saleBatchesForForm(batches, editing, null);
  final options = <V2PenjualanPanen>[];
  for (final batch in rows) {
    final tanggal = DateTime.tryParse(batch.tanggalPanen ?? '');
    if (tanggal == null) continue;
    options.add(
      V2PenjualanPanen(
        id: batch.id,
        tanggalPanen: tanggal,
        sisaKg: batch.stokTersedia,
      ),
    );
  }
  options.sort((a, b) => b.tanggalPanen.compareTo(a.tanggalPanen));
  return List.unmodifiable(options);
}