import '../network/json_utils.dart';

String formatRelativeTime(DateTime? time, {String fallback = '-'}) {
  if (time == null) return fallback;
  final diff = DateTime.now().difference(time.toLocal());
  if (diff.isNegative || diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return _plural(diff.inMinutes, 'minute');
  if (diff.inDays < 1) return _plural(diff.inHours, 'hour');
  if (diff.inDays < 7) return _plural(diff.inDays, 'day');
  if (diff.inDays < 30) return _plural(diff.inDays ~/ 7, 'week');
  if (diff.inDays < 365) {
    final months = diff.inDays ~/ 30;
    if (months == 6) return 'half a year ago';
    return _plural(months, 'month');
  }
  return _plural(diff.inDays ~/ 365, 'year');
}

String formatRelativeTimestamp(Object? raw, {String fallback = ''}) {
  final time = parseFlexibleTimestamp(raw);
  if (time == null) {
    final text = asString(raw).trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }
  return formatRelativeTime(time, fallback: fallback);
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

String _plural(int value, String unit) {
  return '$value $unit${value == 1 ? '' : 's'} ago';
}
