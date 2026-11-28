import '../../../../core/uuid.dart';
import '../../data/pest_models.dart';
import '../../data/pest_repository.dart';

/// Terima atau tolak satu rekomendasi, dipakai halaman pindai dan riwayat.
///
/// Kunci idempotensi melekat pada isi keputusan: kiriman ulang setelah respons hilang memakai
/// kunci dan isi yang sama (ARCHITECTURE.md, "Bila respons server hilang"), sedangkan isi yang
/// berbeda mendapat kunci baru sehingga server menjawabnya dengan benar. Ketuk ganda diabaikan.
class RecommendationDecider {
  RecommendationDecider(this._repo);

  final PestRepository _repo;
  final Map<String, String> _keys = {};
  final Set<String> _inFlight = {};

  String _key(String id, String action, String body) =>
      _keys.putIfAbsent('$id|$action|$body', generateUuidV4);

  /// Null bila keputusan untuk rekomendasi ini masih berjalan.
  Future<PestRecommendation?> accept(
    String id, {
    String? note,
    List<StockLineDraft> materials = const [],
  }) {
    final body =
        '${note ?? ''}|${materials.map((m) => '${m.inventoryId}:${m.amount}:${m.unit}').join(',')}';
    return _run(
      id,
      () => _repo.accept(
        id,
        note: note,
        materials: materials,
        idempotencyKey: _key(id, 'terima', body),
      ),
    );
  }

  Future<PestRecommendation?> reject(
    String id,
    RejectReason? reason, {
    String? note,
  }) => _run(
    id,
    () => _repo.reject(
      id,
      reason,
      note: note,
      idempotencyKey: _key(
        id,
        'tolak',
        '${reason?.apiCode ?? ''}|${note ?? ''}',
      ),
    ),
  );

  Future<PestRecommendation?> _run(
    String id,
    Future<PestRecommendation> Function() call,
  ) async {
    if (!_inFlight.add(id)) return null;
    try {
      return await call();
    } finally {
      _inFlight.remove(id);
    }
  }
}
