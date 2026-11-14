import '../models/penjualan_model.dart';
import 'sale_command.dart';

/// Nilai awal formulir penjualan. Isian yang hasilnya belum pasti didahulukan,
/// supaya yang tampil sama dengan yang akan dikirim ulang.
class SaleFormSeed {
  const SaleFormSeed({
    required this.buyer,
    required this.weight,
    required this.priceText,
    required this.note,
    required this.date,
    required this.status,
    required this.restoredBatch,
  });

  factory SaleFormSeed.from(
    PenjualanItem? item,
    SaleCommand? pending,
    DateTime today,
  ) {
    final line = item != null && item.details.length == 1
        ? item.details.single
        : null;
    final draft = pending?.draft;
    final header = pending?.headerDraft;
    final pendingDate = draft?.date ?? header?.date;
    final pendingStatus = draft?.status ?? header?.status;
    return SaleFormSeed(
      buyer: draft?.buyer ?? header?.buyer ?? item?.pembeli ?? '',
      weight: draft?.quantity ?? line?.jumlahKg ?? 0.0,
      priceText: draft?.priceWire ?? line?.hargaPerKgWire ?? '',
      note:
          (pending == null ? item?.catatan : draft?.note ?? header?.note) ?? '',
      date: pendingDate != null
          ? DateTime.parse(pendingDate)
          : item?.tanggalTransaksi ?? today,
      status: pendingStatus == null
          ? item?.status
          : pendingStatus == 'lunas'
          ? StatusPenjualan.lunas
          : StatusPenjualan.belumLunas,
      // Stok aslinya belum tentu termuat. Stok di sini hanya pengisi, dan
      // formulir tidak menampilkannya selama isian terkunci.
      restoredBatch: draft == null
          ? null
          : BatchPanen(
              id: draft.harvestId,
              nama: 'Panen #${draft.harvestId}',
              stokTersedia: draft.quantity,
            ),
    );
  }

  final String buyer, priceText, note;
  final double weight;
  final DateTime date;
  final StatusPenjualan? status;
  final BatchPanen? restoredBatch;
}
