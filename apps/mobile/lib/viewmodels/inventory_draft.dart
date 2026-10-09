import '../core/uuid.dart';
import '../data/models/inventory_record.dart';

class InventoryDraft {
  const InventoryDraft({
    this.id,
    required this.name,
    required this.categoryId,
    required this.unit,
    required this.minimum,
    required this.initialStock,
  });
  final String? id;
  final String name, categoryId, unit, minimum, initialStock;

  static String? quantityError(String value, {bool positive = false}) {
    if (value.isEmpty) return null;
    if (!RegExp(r'^\d{1,10}(\.\d{1,2})?$').hasMatch(value)) {
      return 'Gunakan maksimal 10 digit dan 2 angka desimal (titik).';
    }
    if (positive && !hasStock(value)) return 'Stok minimum harus lebih dari 0.';
    return null;
  }

  static bool hasStock(String value) =>
      value.isNotEmpty && BigInt.parse(value.replaceAll('.', '')) > BigInt.zero;

  Map<String, String> get errors => {
    if (name.trim().isEmpty || name.length > 100)
      'name': 'Isi nama barang, maksimal 100 karakter.',
    if (quantityError(minimum, positive: true) case final String error)
      'minimum': error,
    if (id == null) ...{
      if (quantityError(initialStock) case final String error) 'stock': error,
    },
  };
}

class InventorySaveCommand {
  InventorySaveCommand(this.draft);
  final InventoryDraft draft;
  final String itemKey = generateUuidV4(), stockKey = generateUuidV4();
  InventoryRecord? item;
  bool uncertain = false;
  bool stockSaved = false, canFinishWithoutStock = false;
  int attempt = 0;
}
