/// Afgangstider vises altid i havnens tid (København og Oslo ligger i samme tidszone), uanset hvilken
/// tidszone telefonen står i – 16:30 er 16:30 også for en kunde i Finland eller England.
///
/// Europe/Copenhagen: CET (UTC+1), sommertid CEST (UTC+2) fra sidste søndag i marts kl. 01:00 UTC til
/// sidste søndag i oktober kl. 01:00 UTC (EU's regel).
DateTime portTime(DateTime t) {
  final utc = t.toUtc();
  final offset = _isSummerTime(utc) ? 2 : 1;
  final shifted = utc.add(Duration(hours: offset));
  // Vægur-tiden i havnen (markeret som UTC, så .hour/.day ikke flyttes igen af telefonens tidszone)
  return DateTime.utc(shifted.year, shifted.month, shifted.day, shifted.hour, shifted.minute, shifted.second);
}

DateTime _lastSunday(int year, int month) {
  final last = DateTime.utc(year, month + 1, 0);
  return last.subtract(Duration(days: last.weekday % 7));
}

bool _isSummerTime(DateTime utc) {
  final start = _lastSunday(utc.year, 3).add(const Duration(hours: 1));
  final end = _lastSunday(utc.year, 10).add(const Duration(hours: 1));
  return !utc.isBefore(start) && utc.isBefore(end);
}

String _two(int n) => n.toString().padLeft(2, '0');

/// HH:MM i havnens tid
String portClock(DateTime t) {
  final p = portTime(t);
  return '${_two(p.hour)}:${_two(p.minute)}';
}

/// YYYY-MM-DD i havnens tid
String portIsoDate(DateTime t) {
  final p = portTime(t);
  return '${p.year}-${_two(p.month)}-${_two(p.day)}';
}
