/// Penampung tulis semaian (penyemaian dan pemindahan) yang belum pasti.
///
/// Hanya memakai data mentah supaya [ConnectedNurseryViewModel] v1 tidak
/// bergantung pada tipe antrean v2.
abstract interface class NurseryQueueSink {
  /// Mencatat (atau memperbarui) tulis yang belum pasti; kunci sama menimpa
  /// baris lama.
  Future<void> record({
    required String key,
    required String target,
    required Map<String, dynamic> body,
    String? subtitle,
    DateTime? createdAt,
  });

  /// Melepas baris setelah tulis yang sama berhasil di jalur normal.
  Future<void> remove(String key);

  /// Menandai baris ditolak pasti server beserta pesannya.
  Future<void> fail(String key, String message);
}
