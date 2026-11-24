import '../widgets/v2_badge.dart';
import 'v2_rawat_data.dart';

/// Badge status rekomendasi untuk satu pindaian; null bila belum ada rekomendasi.
///
/// Dipakai baris “Pindaian terbaru” di tab Rawat dan halaman detail pindaian.
V2Badge? v2PindaiBadge(V2PindaiStatus? status) => switch (status) {
  V2PindaiStatus.menunggu => const V2Badge(
    label: 'Menunggu',
    status: V2BadgeStatus.pending,
  ),
  V2PindaiStatus.diterima => const V2Badge(
    label: 'Diterima',
    status: V2BadgeStatus.success,
  ),
  V2PindaiStatus.ditolak => const V2Badge(
    label: 'Ditolak',
    status: V2BadgeStatus.error,
  ),
  null => null,
};