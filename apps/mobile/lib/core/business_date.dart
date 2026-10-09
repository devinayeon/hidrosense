DateTime jakartaToday([DateTime? now]) {
  final jakarta = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 7));
  return DateTime(jakarta.year, jakarta.month, jakarta.day);
}

String apiDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

Duration untilJakartaMidnight(DateTime now) {
  final utc = now.toUtc();
  final jakarta = utc.add(const Duration(hours: 7));
  final next = DateTime.utc(
    jakarta.year,
    jakarta.month,
    jakarta.day + 1,
  ).subtract(const Duration(hours: 7));
  return next.difference(utc);
}
