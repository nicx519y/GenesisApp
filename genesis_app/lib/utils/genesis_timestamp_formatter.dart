import '../network/json_utils.dart';

String formatGenesisTimestamp(
  Object? raw, {
  String fallback = '',
  DateTime? now,
}) {
  final time = parseFlexibleTimestamp(raw);
  if (time == null) {
    final text = asString(raw).trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }
  return formatGenesisDateTime(time, fallback: fallback, now: now);
}

String formatGenesisDateTime(
  DateTime? time, {
  String fallback = '',
  DateTime? now,
}) {
  if (time == null) return fallback;
  final local = time.toLocal();
  final localNow = (now ?? DateTime.now()).toLocal();
  if (_isSameDay(local, localNow)) {
    return '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
  }
  if (local.year == localNow.year) {
    return '${local.month}-${local.day} '
        '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
  }
  return '${local.year}-${local.month}-${local.day}';
}

DateTime? parseFlexibleTimestamp(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is num) return _dateTimeFromEpoch(raw);
  final text = raw.toString().trim();
  if (text.isEmpty) return null;
  final numeric = num.tryParse(text);
  if (numeric != null) return _dateTimeFromEpoch(numeric);
  return DateTime.tryParse(text) ??
      DateTime.tryParse(text.replaceFirst(' ', 'T'));
}

DateTime _dateTimeFromEpoch(num value) {
  final intValue = value.toInt();
  final millis = intValue.abs() >= 1000000000000 ? intValue : intValue * 1000;
  return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

const List<String> _shortMonths = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Compact recency used by the 9l Home rows: `4m`, `2h`, `3d`, then `Jul 20`
/// once the entry is more than a week old, and a year suffix beyond this year.
String formatGenesisRelativeTimestamp(
  Object? raw, {
  String fallback = '',
  DateTime? now,
}) {
  final time = parseFlexibleTimestamp(raw);
  if (time == null) return fallback;
  final local = time.toLocal();
  final localNow = (now ?? DateTime.now()).toLocal();
  final elapsed = localNow.difference(local);

  if (elapsed.isNegative) return 'now';
  if (elapsed.inMinutes < 1) return 'now';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}m';
  if (elapsed.inHours < 24) return '${elapsed.inHours}h';
  if (elapsed.inDays < 7) return '${elapsed.inDays}d';

  final month = _shortMonths[local.month - 1];
  if (local.year == localNow.year) return '$month ${local.day}';
  return '$month ${local.day}, ${local.year}';
}
