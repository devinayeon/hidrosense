// lib/models/meja_nft_model.dart

enum MejaStatus { aktif, perawatan }

class MejaNft {
  final String id;
  final String name; // contoh: "Meja NFT #01"
  final MejaStatus status;
  final int capacityUsed;
  final int capacityTotal;
  final String? batchName; // contoh: "Batch #03"
  final String? variety; // contoh: "Selada Grand Rapids"
  final int? hss; // contoh: 28
  final String? maintenanceNote; // contoh: "Pembersihan Lumut"
  final String?
  maintenanceEta; // contoh: "Estimasi selesai pembersihan besok sore"

  const MejaNft({
    required this.id,
    required this.name,
    required this.status,
    this.capacityUsed = 0,
    required this.capacityTotal,
    this.batchName,
    this.variety,
    this.hss,
    this.maintenanceNote,
    this.maintenanceEta,
  });
}
