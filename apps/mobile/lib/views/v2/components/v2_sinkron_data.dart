/// Model dan data contoh alur "11 Sinkron & Profil".
///
/// Satu baris antrean mewakili satu data yang tersimpan di HP dan sedang
/// menunggu dikirim ke server. Kolom kanan baris menampilkan kode data
/// (mis. `10.04`), bukan nilai uang, dan lencananya berasal dari
/// [V2SinkronStatus].
library;

import '../../../data/models/sync_queue_item.dart';

/// Jenis data yang ikut disinkronkan; menentukan ikon dan nada lingkaran lead.
enum V2SinkronJenis { semaian, stok, panen, penjualan, rusak }

/// Keadaan satu data di antrean sinkron.
enum V2SinkronStatus {
  /// Sudah ada di server (frame 11.5: Semaian, Stok, Panen).
  terkirim,

  /// Masih menunggu dikirim (frame 11.4 dan 11.5).
  antrean,

  /// Ditolak server dan perlu diperbaiki atau dipilih versinya (frame 11.7).
  gagal,
}

/// Satu baris `StockItem` di daftar sinkron.
class V2SinkronItem {
  const V2SinkronItem({
    required this.jenis,
    required this.subtitle,
    required this.kode,
    required this.status,
    this.nama,
    this.konflik = false,
  });

  final V2SinkronJenis jenis;

  /// Baris kedua: nama varietas, meja, atau alasan gagal.
  final String subtitle;

  /// Nama data asli (mis. pembeli); dipakai dialog konflik 11.8.
  final String? nama;

  /// Baris bentrok versi: ketuk membuka dialog 11.8, bukan form perbaikan.
  final bool konflik;

  /// Kode data di kolom kanan, mis. `10.04`.
  final String kode;

  final V2SinkronStatus status;

  String get title => switch (jenis) {
    V2SinkronJenis.semaian => 'Semaian',
    V2SinkronJenis.stok => 'Stok',
    V2SinkronJenis.panen => 'Panen',
    V2SinkronJenis.penjualan => 'Penjualan',
    V2SinkronJenis.rusak => 'Rusak',
  };
}

/// Kode kolom kanan tiap jenis data (frame 11.4/11.5).
String kodeSinkronJenis(V2SinkronJenis jenis) => switch (jenis) {
  V2SinkronJenis.semaian || V2SinkronJenis.stok => '10.02',
  V2SinkronJenis.panen => '10.03',
  V2SinkronJenis.penjualan => '10.04',
  V2SinkronJenis.rusak => '10.05',
};

/// Baris antrean nyata dari HP; keadaannya mengikuti [SyncQueueItem.status].
///
/// Baris yang ditolak server memakai pesan penolakannya sebagai subjudul
/// (frame 11.7: "Sisa panen kurang"), jadi pengguna tahu apa yang harus
/// diperbaiki tanpa membuka barisnya.
List<V2SinkronItem> v2SinkronItemsFromQueue(List<SyncQueueItem> items) {
  final result = <V2SinkronItem>[];
  for (final item in items) {
    result.add(_sinkronItemOf(item, null));
  }
  return List.unmodifiable(result);
}

/// Baris antrean dengan status hasil putaran berjalan (frame 11.5).
///
/// [status] berisi status per kunci baris; baris yang belum punya status
/// memakai status tersimpan, jadi baris yang belum sempat dikirim tetap
/// tampil "Antrean".
List<V2SinkronItem> v2SinkronItemsWithStatus(
  List<SyncQueueItem> items,
  Map<String, V2SinkronStatus> status,
) {
  final result = <V2SinkronItem>[];
  for (final item in items) {
    result.add(_sinkronItemOf(item, status[item.key]));
  }
  return List.unmodifiable(result);
}

/// Satu baris dari antrean; [override] adalah status hasil putaran berjalan.
V2SinkronItem _sinkronItemOf(
  SyncQueueItem item,
  V2SinkronStatus? override,
) {
  final jenis = _sinkronJenisOf(item.jenis);
  final konflik = item.status == SyncQueueStatus.konflik;
  final gagal = item.status == SyncQueueStatus.gagal;
  return V2SinkronItem(
    jenis: jenis,
    nama: item.subtitle,
    subtitle: konflik
        ? 'Berubah di server'
        : gagal
        ? (item.error ?? item.subtitle)
        : item.subtitle,
    kode: kodeSinkronJenis(jenis),
    status:
        override ??
        (konflik || gagal
            ? V2SinkronStatus.gagal
            : V2SinkronStatus.antrean),
    konflik: konflik,
  );
}

V2SinkronJenis _sinkronJenisOf(SyncQueueJenis jenis) => switch (jenis) {
  SyncQueueJenis.semaian => V2SinkronJenis.semaian,
  SyncQueueJenis.stok => V2SinkronJenis.stok,
  SyncQueueJenis.panen => V2SinkronJenis.panen,
  SyncQueueJenis.penjualan => V2SinkronJenis.penjualan,
  SyncQueueJenis.rusak => V2SinkronJenis.rusak,
};

/// Nada lencana ringkasan: hijau "Terkini", merah "Gagal N", atau biru
/// "Antrean N" saat sisa data hanya menunggu (bukan ditolak).
enum V2SinkronRingkasanTone { terkini, gagal, antrean }

/// Isi `SummaryCard` di puncak halaman sinkron.
class V2SinkronRingkasan {
  const V2SinkronRingkasan({
    required this.kicker,
    required this.value,
    required this.meta,
    required this.extra,
    required this.badgeLabel,
    this.tone = V2SinkronRingkasanTone.terkini,
  });

  final String kicker;

  /// Nilai besar: jam sinkron terakhir atau jumlah data yang terkirim.
  final String value;
  final String meta;
  final String extra;
  final String badgeLabel;

  /// Nada lencana; frame 11.7/11.8 memakai merah, sisa antrean memakai biru.
  final V2SinkronRingkasanTone tone;
}

/// Ringkasan frame 11.1: semuanya sudah di server.
const V2SinkronRingkasan designSinkronTerkini = V2SinkronRingkasan(
  kicker: 'Terakhir sinkron',
  value: '09.40',
  meta: 'Semua data sudah di server',
  extra: 'Antrean kosong',
  badgeLabel: 'Terkini',
);

/// Ringkasan frame 11.6: sinkron baru selesai pukul 10.06.
const V2SinkronRingkasan designSinkronSelesai = V2SinkronRingkasan(
  kicker: 'Terakhir sinkron',
  value: '10.06',
  meta: 'Semua data sudah di server',
  extra: 'Antrean kosong',
  badgeLabel: 'Terkini',
);

/// Ringkasan frame 11.7/11.8: tiga dari lima data berhasil.
const V2SinkronRingkasan designSinkronSebagian = V2SinkronRingkasan(
  kicker: 'Sinkron gagal sebagian',
  value: '3 dari 5 terkirim',
  meta: '2 data masih di HP',
  extra: 'Ketuk data untuk memperbaiki',
  badgeLabel: 'Gagal 2',
  tone: V2SinkronRingkasanTone.gagal,
);

/// Ringkasan 11.6 dari putaran nyata: jam selesai diambil dari perangkat.
V2SinkronRingkasan v2SinkronRingkasanSelesai(DateTime waktu) {
  final jam = waktu.hour.toString().padLeft(2, '0');
  final menit = waktu.minute.toString().padLeft(2, '0');
  return V2SinkronRingkasan(
    kicker: 'Terakhir sinkron',
    value: '$jam.$menit',
    meta: 'Semua data sudah di server',
    extra: 'Antrean kosong',
    badgeLabel: 'Terkini',
  );
}

/// Ringkasan 11.7 dari putaran nyata.
///
/// [remaining] adalah semua baris yang belum terkirim (ditolak maupun masih
/// menunggu), jadi "x dari y terkirim" selalu sama dengan isi antrean.
V2SinkronRingkasan v2SinkronRingkasanSebagian({
  required int sent,
  required int remaining,
  required int failed,
}) {
  final gagal = failed > 0;
  return V2SinkronRingkasan(
    kicker: gagal ? 'Sinkron gagal sebagian' : 'Sinkron belum selesai',
    value: '$sent dari ${sent + remaining} terkirim',
    meta: '$remaining data masih di HP',
    extra: gagal
        ? 'Ketuk data untuk memperbaiki'
        : 'Akan dicoba lagi saat online',
    badgeLabel: gagal ? 'Gagal $failed' : 'Antrean $remaining',
    tone: gagal
        ? V2SinkronRingkasanTone.gagal
        : V2SinkronRingkasanTone.antrean,
  );
}

/// Lima baris frame 11.4: perangkat offline, belum ada yang terkirim.
const List<V2SinkronItem> designSinkronAntrean = <V2SinkronItem>[
  V2SinkronItem(
    jenis: V2SinkronJenis.semaian,
    subtitle: 'Romaine',
    kode: '10.02',
    status: V2SinkronStatus.antrean,
  ),
  V2SinkronItem(
    jenis: V2SinkronJenis.stok,
    subtitle: 'Lollo Rossa',
    kode: '10.02',
    status: V2SinkronStatus.antrean,
  ),
  V2SinkronItem(
    jenis: V2SinkronJenis.panen,
    subtitle: 'Meja B1',
    kode: '10.03',
    status: V2SinkronStatus.antrean,
  ),
  V2SinkronItem(
    jenis: V2SinkronJenis.penjualan,
    subtitle: 'Warung Sari',
    kode: '10.04',
    status: V2SinkronStatus.antrean,
  ),
  V2SinkronItem(
    jenis: V2SinkronJenis.rusak,
    subtitle: 'Meja A2',
    kode: '10.05',
    status: V2SinkronStatus.antrean,
  ),
];

/// Lima baris frame 11.5: tiga data sudah terkirim, dua masih antre.
const List<V2SinkronItem> designSinkronBerjalan = <V2SinkronItem>[
  V2SinkronItem(
    jenis: V2SinkronJenis.semaian,
    subtitle: 'Romaine',
    kode: '10.02',
    status: V2SinkronStatus.terkirim,
  ),
  V2SinkronItem(
    jenis: V2SinkronJenis.stok,
    subtitle: 'Lollo Rossa',
    kode: '10.02',
    status: V2SinkronStatus.terkirim,
  ),
  V2SinkronItem(
    jenis: V2SinkronJenis.panen,
    subtitle: 'Meja B1',
    kode: '10.03',
    status: V2SinkronStatus.terkirim,
  ),
  V2SinkronItem(
    jenis: V2SinkronJenis.penjualan,
    subtitle: 'Warung Sari',
    kode: '10.04',
    status: V2SinkronStatus.antrean,
  ),
  V2SinkronItem(
    jenis: V2SinkronJenis.rusak,
    subtitle: 'Meja A2',
    kode: '10.05',
    status: V2SinkronStatus.antrean,
  ),
];

/// Dua baris frame 11.7/11.8: yang gagal saja, dengan alasan di subjudul.
const List<V2SinkronItem> designSinkronGagal = <V2SinkronItem>[
  V2SinkronItem(
    jenis: V2SinkronJenis.penjualan,
    subtitle: 'Sisa panen kurang',
    kode: '10.04',
    status: V2SinkronStatus.gagal,
  ),
  V2SinkronItem(
    jenis: V2SinkronJenis.rusak,
    subtitle: 'Berubah di server',
    kode: '10.05',
    status: V2SinkronStatus.gagal,
    nama: 'Meja A2',
    konflik: true,
  ),
];
