const List<String> _namaBulan = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

/// Format tanggal bahasa Indonesia TANPA bergantung pada
/// initializeDateFormatting('id_ID') sehingga tidak bisa melempar error.
/// singkat = false -> "06 Oktober 2026", singkat = true -> "06 Okt 2026"
String formatTanggalIndo(DateTime d, {bool singkat = false}) {
  final hari = d.day.toString().padLeft(2, '0');
  final bulan = _namaBulan[d.month - 1];
  final bulanText = singkat && bulan.length > 3 ? bulan.substring(0, 3) : bulan;
  return '$hari $bulanText ${d.year}';
}

/// 50.0 -> "50", 2.5 -> "2.5"
String formatAngka(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}
