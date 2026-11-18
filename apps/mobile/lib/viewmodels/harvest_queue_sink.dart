/// Penampung tulis panen yang hasilnya belum pasti.
///
/// Antarmuka ini sengaja hanya memakai data mentah supaya [PanenViewModel] v1
/// tidak bergantung pada penyimpanan antrean v2.
abstract interface class HarvestQueueSink {
  /// Mencatat (atau memperbarui) tulis yang belum pasti; kunci sama menimpa
  /// baris lama.
  Future<void> record({
    required String key,
    required String target,
    required Map<String, dynamic> body,
    DateTime? createdAt,
  });

  /// Melepas baris setelah tulis yang sama berhasil di jalur normal.
  Future<void> remove(String key);

  /// Menandai baris ditolak pasti server beserta pesannya.
  Future<void> fail(String key, String message);
}
