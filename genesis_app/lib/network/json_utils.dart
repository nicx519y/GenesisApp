import '../utils/genesis_image_resource.dart';
import '../ui/text/genesis_text_input_formatters.dart';

Object? jsonValue(Object? v) => v;

Map<String, dynamic> asJsonMap(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) {
    return v.map((key, value) => MapEntry(key.toString(), value));
  }
  throw ArgumentError('Expected JSON map, got ${v.runtimeType}');
}

List asJsonList(Object? v) {
  if (v is List) return v;
  throw ArgumentError('Expected JSON list, got ${v.runtimeType}');
}

String asString(Object? v, {String fallback = ''}) {
  if (v == null) return genesisDisplaySafeText(fallback);
  return genesisDisplaySafeText(v.toString());
}

String asImageUrl(Object? v, {Object? fallback}) {
  return GenesisImageResourceRegistry.register(
    GenesisImageResource.fromJson(v, fallback: fallback),
  ).displayUrl;
}

String asResolvedImageUrl(
  Object? v,
  String Function(String url) resolver, {
  Object? fallback,
}) {
  return GenesisImageResourceRegistry.register(
    GenesisImageResource.fromJson(v, fallback: fallback).mapUrls(resolver),
  ).displayUrl;
}

int asInt(Object? v, {int fallback = 0}) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

bool asBool(Object? v, {bool fallback = false}) {
  if (v is bool) return v;
  if (v is String) {
    if (v.toLowerCase() == 'true') return true;
    if (v.toLowerCase() == 'false') return false;
  }
  if (v is num) return v != 0;
  return fallback;
}

DateTime? asDateTime(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is num) return _dateTimeFromEpoch(v);
  if (v is String) {
    final numeric = num.tryParse(v);
    if (numeric != null) return _dateTimeFromEpoch(numeric);
    return DateTime.tryParse(v);
  }
  return null;
}

DateTime _dateTimeFromEpoch(num value) {
  final intValue = value.toInt();
  final millis = intValue.abs() >= 1000000000000 ? intValue : intValue * 1000;
  return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
}
