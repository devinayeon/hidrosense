// lib/models/meja_nft_model.dart

enum MejaStatus { aktif, perawatan }

class MejaNft {
  final String id;
  final String name; // contoh: "Meja NFT #01"
  final String systemType; // contoh: "Sistem NFT"
  final String location; // contoh: "Lokasi Green House Barat"
  final MejaStatus status;
  final int capacityUsed;
  final int capacityTotal;
  final int healthyCount;
  final int failedCount;
  final String? batchName;
  final String? variety;
  final int? hss;
  final String? estimatedHarvestDate;
  final String? maintenanceNote;
  final String? maintenanceEta;
  final String? notes; // Catatan / Spesifikasi

  const MejaNft({
    required this.id,
    required this.name,
    this.systemType = 'Sistem NFT',
    this.location = 'Lokasi Green House Barat',
    required this.status,
    this.capacityUsed = 0,
    required this.capacityTotal,
    this.healthyCount = 0,
    this.failedCount = 0,
    this.batchName,
    this.variety,
    this.hss,
    this.estimatedHarvestDate,
    this.maintenanceNote,
    this.maintenanceEta,
    this.notes,
  });

  double get occupancyPercentage =>
      capacityTotal > 0 ? (capacityUsed / capacityTotal) : 0.0;

  MejaNft copyWith({
    String? id,
    String? name,
    String? systemType,
    String? location,
    MejaStatus? status,
    int? capacityUsed,
    int? capacityTotal,
    int? healthyCount,
    int? failedCount,
    String? batchName,
    String? variety,
    int? hss,
    String? estimatedHarvestDate,
    String? maintenanceNote,
    String? maintenanceEta,
    String? notes,
  }) {
    return MejaNft(
      id: id ?? this.id,
      name: name ?? this.name,
      systemType: systemType ?? this.systemType,
      location: location ?? this.location,
      status: status ?? this.status,
      capacityUsed: capacityUsed ?? this.capacityUsed,
      capacityTotal: capacityTotal ?? this.capacityTotal,
      healthyCount: healthyCount ?? this.healthyCount,
      failedCount: failedCount ?? this.failedCount,
      batchName: batchName ?? this.batchName,
      variety: variety ?? this.variety,
      hss: hss ?? this.hss,
      estimatedHarvestDate: estimatedHarvestDate ?? this.estimatedHarvestDate,
      maintenanceNote: maintenanceNote ?? this.maintenanceNote,
      maintenanceEta: maintenanceEta ?? this.maintenanceEta,
      notes: notes ?? this.notes,
    );
  }
}
