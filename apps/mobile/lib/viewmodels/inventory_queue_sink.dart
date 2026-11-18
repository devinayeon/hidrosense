/// Penampung tulis inventaris yang belum pasti.
///
/// Satu simpanan bisa terdiri dari dua tahap (barang lalu saldo awal), jadi
/// kuncinya dipisah dan antarmuka ini hanya memakai data mentah.
abstract interface class InventoryQueueSink {
  /// Mencatat (atau memperbarui) satu tahap tulis yang belum pasti; kunci sama
  /// menimpa baris lama.
  Future<void> record({
    required String key,
    required String target,
    required Map<String, dynamic> body,
    required String subtitle,
    DateTime? createdAt,
  });

  /// Melepas baris setelah tahap yang sama berhasil di jalur normal.
  Future<void> remove(String key);

  /// Menandai baris ditolak pasti server beserta pesannya.
  Future<void> fail(String key, String message);
}
