import '../../../data/models/inventory_record.dart';
import '../../../data/models/nursery_record.dart';
import '../../../viewmodels/v2_beranda_viewmodel.dart';
import '../pages/v2_notifications_page.dart';
import '../widgets/v2_icon.dart';

/// Notifikasi nyata halaman "2.4 Notifikasi" yang dibuka dari Beranda.
///
/// Setiap pengingat yang masih berlaku diberi id stabil supaya status "sudah
/// dibaca" bisa disimpan per pengguna ([sudahDibaca]):
/// - semaian aktif yang genap HSS 15 (siap pindah), satu baris per batch;
/// - satu ringkasan barang yang di bawah stok minimum (termasuk yang habis).
///
/// `target` menunjuk tab Beranda yang relevan supaya ketukan membuka tujuan
/// yang benar (BUG-30). Daftar kosong berarti tidak ada yang perlu
/// diberitahukan, sehingga pemanggil bisa menampilkan halaman tanpa baris palsu.
List<V2NotificationGroup> v2BerandaNotifikasi({
  required List<SowingRecord> nursery,
  required List<InventoryRecord> inventaris,
  Set<String> sudahDibaca = const <String>{},
}) {
  final siapPindah = nursery.where((item) => item.canTransfer).toList();
  final stokMenipis = inventaris.where(isBerandaLowStock).toList();
  final items = <V2Notification>[
    for (final semai in siapPindah)
      V2Notification(
        id: 'semaian-${semai.id}',
        title: 'Semaian HSS 15',
        subtitle: '${semai.batchName} siap pindah ke meja (${semai.hssText})',
        read: sudahDibaca.contains('semaian-${semai.id}'),
        target: V2NotificationTarget.semaian,
      ),
    if (stokMenipis.isNotEmpty)
      V2Notification(
        id: 'stok-menipis',
        title: 'Stok menipis',
        subtitle: '${stokMenipis.length} barang di bawah minimum stok',
        icon: V2IconName.box,
        read: sudahDibaca.contains('stok-menipis'),
        target: V2NotificationTarget.stok,
      ),
  ];
  if (items.isEmpty) return const <V2NotificationGroup>[];
  return <V2NotificationGroup>[V2NotificationGroup(label: 'Baru', items: items)];
}
