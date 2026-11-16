import '../core/formatting.dart';
import '../data/models/harvest_record.dart';
import '../data/models/sale_record.dart';
import '../models/penjualan_model.dart';

double _minorToDouble(BigInt minor) => minor.toDouble() / 100;

double _roundKg(double weight) => double.parse(weight.toStringAsFixed(2));

/// Menghitung stok tiap batch setelah satu penjualan dibuat atau dikoreksi:
/// baris lama dikembalikan ke stok, baris baru mengurangi stok.
List<BatchPanen> adjustBatches(
  List<BatchPanen> batches,
  PenjualanItem? oldItem,
  PenjualanItem newItem,
) {
  final deltas = <String, double>{};
  for (final detail in oldItem?.details ?? const <PenjualanLine>[]) {
    deltas[detail.idPanen] = (deltas[detail.idPanen] ?? 0) + detail.jumlahKg;
  }
  for (final detail in newItem.details) {
    deltas[detail.idPanen] = (deltas[detail.idPanen] ?? 0) - detail.jumlahKg;
  }
  return List.unmodifiable(
    batches.map((batch) {
      final delta = deltas[batch.id];
      if (delta == null) return batch;
      final stock = _roundKg(batch.stokTersedia + delta);
      return batch.copyWith(stokTersedia: stock < 0 ? 0 : stock);
    }),
  );
}

/// Stok tiap panen = berat layak dikurangi semua yang sudah terjual.
List<BatchPanen> toBatches(
  List<HarvestRecord> harvests,
  List<SaleRecord> records,
) {
  final sold = <String, BigInt>{};
  for (final record in records) {
    for (final detail in record.details) {
      sold[detail.harvestId] =
          (sold[detail.harvestId] ?? BigInt.zero) + detail.quantity.minor;
    }
  }
  return List.unmodifiable(
    harvests.map((harvest) {
      final remaining =
          harvest.saleable.minor - (sold[harvest.id] ?? BigInt.zero);
      final stock = remaining > BigInt.zero ? remaining : BigInt.zero;
      final date = DateTime.parse(harvest.date);
      return BatchPanen(
        id: harvest.id,
        nama:
            'Panen #${harvest.id} · '
            '${formatTanggalIndo(date, singkat: true)}',
        stokTersedia: _minorToDouble(stock),
        tanggalPanen: harvest.date,
      );
    }),
  );
}

PenjualanItem toPenjualanItem(SaleRecord record) {
  final lines = List<PenjualanLine>.unmodifiable(
    record.details.map(
      (detail) => PenjualanLine(
        idPanen: detail.harvestId,
        tanggalPanen: detail.harvestDate,
        jumlahKg: _minorToDouble(detail.quantity.minor),
        hargaPerKg: detail.price,
        hargaPerKgWire: detail.priceWire,
        totalHarga: detail.total,
        beratLayak: detail.saleable == null
            ? null
            : _minorToDouble(detail.saleable!.minor),
      ),
    ),
  );
  final quantity = lines.fold(0.0, (sum, line) => sum + line.jumlahKg);
  final date = DateTime.parse(record.date);
  return PenjualanItem(
    id: record.id,
    pembeli: record.buyer,
    tanggal: formatTanggalIndo(date, singkat: true),
    tanggalIso: record.date,
    kuantitas: '${formatAngka(quantity)} Kg',
    totalHarga: lines.fold(0.0, (sum, line) => sum + line.totalHarga),
    status: record.status == 'lunas'
        ? StatusPenjualan.lunas
        : StatusPenjualan.belumLunas,
    catatan: record.note,
    batchPanenId: lines.length == 1 ? lines.first.idPanen : null,
    version: record.version,
    details: lines,
  );
}

/// Urutan daftar: tanggal terbaru dulu, lalu id terbesar.
int comparePenjualanItems(PenjualanItem a, PenjualanItem b) {
  final aDate = a.tanggalIso, bDate = b.tanggalIso;
  if (aDate != null && bDate != null) {
    final byDate = bDate.compareTo(aDate);
    if (byDate != 0) return byDate;
  } else if (aDate != null) {
    return -1;
  } else if (bDate != null) {
    return 1;
  }
  final aId = BigInt.tryParse(a.id) ?? BigInt.zero;
  final bId = BigInt.tryParse(b.id) ?? BigInt.zero;
  return bId.compareTo(aId);
}

/// Batch untuk koreksi saat data panen belum termuat, memakai data baris itu.
BatchPanen fallbackSaleBatch(PenjualanLine line) {
  final date = DateTime.parse(line.tanggalPanen);
  return BatchPanen(
    id: line.idPanen,
    nama:
        'Panen #${line.idPanen} · '
        '${formatTanggalIndo(date, singkat: true)}',
    stokTersedia: line.jumlahKg,
    tanggalPanen: line.tanggalPanen,
  );
}

/// Batch yang harus dipilih formulir koreksi, atau null bila pilihannya sudah
/// sesuai atau pengguna sudah memilih batch lain.
BatchPanen? editBatchSyncTarget(
  List<BatchPanen> batches,
  PenjualanLine line,
  BatchPanen? selected,
) {
  if (selected != null && selected.id != line.idPanen) return null;
  final target = batches.firstWhere(
    (batch) => batch.id == line.idPanen,
    orElse: () => batches.first,
  );
  final inSync =
      selected != null &&
      selected.id == target.id &&
      selected.nama == target.nama &&
      (selected.stokTersedia - target.stokTersedia).abs() < 0.001;
  return inSync ? null : target;
}

/// Pilihan batch di formulir. Saat koreksi, stok batch miliknya ditambah berat
/// baris itu, karena berat tersebut akan kembali ke stok bila diubah.
List<BatchPanen> saleBatchesForForm(
  List<BatchPanen> allBatches,
  PenjualanItem? item,
  BatchPanen? selected,
) {
  final line = item != null && item.details.length == 1
      ? item.details.single
      : null;
  if (line == null) {
    final available = allBatches
        .where((batch) => batch.stokTersedia > 0)
        .toList();
    if (selected != null &&
        !available.any((batch) => batch.id == selected.id)) {
      available.insert(0, selected);
    }
    return List.unmodifiable(available);
  }
  final matched = allBatches.where((batch) => batch.id == line.idPanen);
  final current = matched.isEmpty
      ? fallbackSaleBatch(line)
      : matched.first.copyWith(
          stokTersedia: _roundKg(matched.first.stokTersedia + line.jumlahKg),
        );
  return List.unmodifiable([
    current,
    ...allBatches.where(
      (batch) => batch.id != line.idPanen && batch.stokTersedia > 0,
    ),
  ]);
}
