/// Seed derived from the UTC date, so today's endless run is the same run
/// for anyone who punches in on the same calendar day, with no server.
///
/// The global-leaderboard half of a daily challenge is rejected: the scope
/// ceiling allows zero backend calls.
int dailySeed([DateTime? now]) {
  final day = (now ?? DateTime.now()).toUtc();
  return day.year * 10000 + day.month * 100 + day.day;
}

/// `YYYY-MM-DD` in UTC, for the home row.
String dailyStamp([DateTime? now]) {
  final day = (now ?? DateTime.now()).toUtc();
  final month = day.month.toString().padLeft(2, '0');
  final date = day.day.toString().padLeft(2, '0');
  return '${day.year}-$month-$date';
}
