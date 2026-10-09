import '../core/business_date.dart';
import '../core/uuid.dart';
import '../data/models/nursery_record.dart';

class SowingDraft {
  const SowingDraft({
    this.id,
    required this.date,
    required this.seedCount,
    required this.note,
    this.inventoryId,
    this.amount = '',
    this.unit = '',
  });
  final String? id, inventoryId;
  final String date, note, amount, unit;
  final int seedCount;

  Map<String, String> get errors {
    final parsed = DateTime.tryParse(date);
    return {
      if (parsed == null ||
          apiDate(parsed) != date ||
          (id == null && date.compareTo(apiDate(jakartaToday())) > 0))
        'date': 'Gunakan tanggal semai yang valid, paling lambat hari ini.',
      if (seedCount < 1 || seedCount > 1000000)
        'count': 'Jumlah benih harus 1 sampai 1.000.000 butir.',
      if (note.length > 1000) 'note': 'Catatan maksimal 1.000 karakter.',
      if (id == null && inventoryId == null)
        'seed': 'Pilih benih aktif dari inventaris.',
      if (id == null &&
          (!RegExp(r'^\d{1,10}(\.\d{1,2})?$').hasMatch(amount) ||
              int.parse(amount.replaceAll('.', '')) <= 0))
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
