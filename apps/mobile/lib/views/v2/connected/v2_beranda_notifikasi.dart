import '../../../data/models/inventory_record.dart';
import '../../../data/models/nursery_record.dart';
import '../../../viewmodels/v2_beranda_viewmodel.dart';
import '../pages/v2_notifications_page.dart';
import '../widgets/v2_icon.dart';

/// Notifikasi nyata halaman "2.4 Notifikasi" yang dibuka dari Beranda.
///
/// Tanpa penyimpanan "sudah dibaca", semua pengingat yang masih berlaku
/// dikelompokkan sebagai "Baru":
/// - semaian aktif yang genap HSS 15 (siap pindah), satu baris per batch;
/// - satu ringkasan barang yang di bawah stok minimum (termasuk yang habis).
///
/// Daftar kosong berarti tidak ada yang perlu diberitahukan, sehingga pemanggil
/// bisa menampilkan halaman tanpa baris palsu.
List<V2NotificationGroup> v2BerandaNotifikasi({
  required List<SowingRecord> nursery,
  required List<InventoryRecord> inventaris,
}) {
  final siapPindah = nursery.where((item) => item.canTransfer).toList();
  final stokMenipis = inventaris.where(isBerandaLowStock).toList();
  final items = <V2Notification>[
    for (final semai in siapPindah)
      V2Notification(
        title: 'Semaian HSS 15',
        subtitle: '${semai.batchName} siap pindah ke meja (${semai.hssText})',
      ),
    if (stokMenipis.isNotEmpty)
      V2Notification(
        title: 'Stok menipis',
        subtitle: '${stokMenipis.length} barang di bawah minimum stok',
        icon: V2IconName.box,
      ),
  ];
  if (items.isEmpty) return const <V2NotificationGroup>[];
  return <V2NotificationGroup>[V2NotificationGroup(label: 'Baru', items: items)];
}
