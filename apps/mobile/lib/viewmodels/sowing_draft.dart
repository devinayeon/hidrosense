import '../core/business_date.dart';
import '../core/uuid.dart';
import '../data/models/nursery_record.dart';

/// Satu baris `materials[]` POST /penyemaian (kontrak BUG-38).
class SowingMaterialDraft {
  const SowingMaterialDraft({
    required this.inventoryId,
    required this.amount,
    required this.unit,
  });

  final String inventoryId;
  final String amount;
  final String unit;
}

bool _jumlahBahanValid(String amount) =>
    RegExp(r'^\d{1,10}(\.\d{1,2})?$').hasMatch(amount) &&
    int.parse(amount.replaceAll('.', '')) > 0;

class SowingDraft {
  const SowingDraft({
    this.id,
    required this.date,
    required this.seedCount,
    required this.note,
    this.inventoryId,
    this.amount = '',
    this.unit = '',
    this.status,
    this.materials = const <SowingMaterialDraft>[],
  });
  final String? id, inventoryId;

  /// Status penyemaian backend saat mengubah: `aktif` atau `selesai`.
  ///
  /// Null berarti status tidak ikut diubah. Hanya dipakai saat [id] terisi.
  final String? status;

  final String date, note, amount, unit;
  final int seedCount;

  /// Semua bahan untuk penyemaian baru. Bila kosong, dipakai pasangan
  /// [inventoryId]/[amount]/[unit] supaya pemanggil lama tetap jalan.
  final List<SowingMaterialDraft> materials;

  List<SowingMaterialDraft> get daftarBahan => materials.isNotEmpty
      ? materials
      : inventoryId == null
      ? const <SowingMaterialDraft>[]
      : <SowingMaterialDraft>[
          SowingMaterialDraft(
            inventoryId: inventoryId!,
            amount: amount,
            unit: unit,
          ),
        ];

  Map<String, String> get errors {
    final parsed = DateTime.tryParse(date);
    final jumlahDiperiksa = daftarBahan.isNotEmpty
        ? [for (final item in daftarBahan) item.amount]
        : <String>[amount];
    return {
      if (parsed == null ||
          apiDate(parsed) != date ||
          (id == null && date.compareTo(apiDate(jakartaToday())) > 0))
        'date': 'Gunakan tanggal semai yang valid, paling lambat hari ini.',
      if (seedCount < 1 || seedCount > 1000000)
        'count': 'Jumlah benih harus 1 sampai 1.000.000 butir.',
      if (note.length > 1000) 'note': 'Catatan maksimal 1.000 karakter.',
      if (id == null && daftarBahan.isEmpty)
        'seed': 'Pilih benih aktif dari inventaris.',
      if (id == null && jumlahDiperiksa.any((item) => !_jumlahBahanValid(item)))
        'amount': 'Isi pemakaian stok lebih dari 0, maksimal 2 angka desimal.',
    };
  }
}

class SowingCommand {
  SowingCommand(this.draft);
  final SowingDraft draft;
  final String key = generateUuidV4();
  int attempt = 0;
  bool uncertain = false;
  SowingRecord? receipt;
}
