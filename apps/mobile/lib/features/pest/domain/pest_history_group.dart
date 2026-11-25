import '../data/pest_models.dart';

const List<String> _bulan = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

/// Tanggal WIB satu rekomendasi untuk pengelompokan riwayat (D-28).
///
/// Tanggal aplikasi (`tanggal_aplikasi`) sudah berupa tanggal WIB; kalau belum
/// diterima, waktu rekomendasi dikonversi dari UTC ke WIB (+7 jam) lebih dulu
/// supaya entri tengah malam tidak masuk kelompok hari yang salah.
DateTime tanggalWibRekomendasi(PestRecommendation item) {
  final applied = item.appliedOn;
  if (applied != null) {
    final parsed = DateTime.tryParse(applied);
    if (parsed != null) {
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
  }
  final wib = item.createdAt.toUtc().add(const Duration(hours: 7));
  return DateTime(wib.year, wib.month, wib.day);
}

/// `24 Nov 2026`.
String labelTanggalWib(DateTime tanggal) =>
    '${tanggal.day} ${_bulan[tanggal.month - 1]} ${tanggal.year}';

/// Satu kelompok riwayat dengan header tanggal WIB-nya.
class RiwayatHarian {
  const RiwayatHarian({required this.tanggal, required this.items});

  final DateTime tanggal;
  final List<PestRecommendation> items;

  String get label => labelTanggalWib(tanggal);
}

/// Saring riwayat ke rentang tanggal WIB, dari–sampai inklusif (D-32).
///
/// Batas tanggal saja (jam diabaikan) supaya entri pada hari terakhir ikut
/// tampil. Null berarti batas itu terbuka.
List<PestRecommendation> saringRiwayatTanggal(
  List<PestRecommendation> items, {
  DateTime? dari,
  DateTime? sampai,
}) {
  final awal = dari == null ? null : DateTime(dari.year, dari.month, dari.day);
  final akhir = sampai == null
      ? null
      : DateTime(sampai.year, sampai.month, sampai.day);
  return <PestRecommendation>[
    for (final item in items)
      if ((awal == null || !tanggalWibRekomendasi(item).isBefore(awal)) &&
          (akhir == null || !tanggalWibRekomendasi(item).isAfter(akhir)))
        item,
  ];
}

/// Kelompokkan riwayat per tanggal WIB, tanpa mengubah urutan kemunculan.
///
/// Urutan grup mengikuti kemunculan pertama di [items] supaya urutan terbaru
/// dari server tetap terjaga, termasuk saat halaman berikutnya dimuat.
List<RiwayatHarian> kelompokkanRiwayatPerTanggal(
  List<PestRecommendation> items,
) {
  final urutan = <DateTime>[];
  final perTanggal = <DateTime, List<PestRecommendation>>{};
  for (final item in items) {
    final tanggal = tanggalWibRekomendasi(item);
    final daftar = perTanggal.putIfAbsent(tanggal, () {
      urutan.add(tanggal);
      return <PestRecommendation>[];
    });
    daftar.add(item);
  }
  return <RiwayatHarian>[
    for (final tanggal in urutan)
      RiwayatHarian(
        tanggal: tanggal,
        items: List<PestRecommendation>.unmodifiable(perTanggal[tanggal]!),
      ),
  ];
}