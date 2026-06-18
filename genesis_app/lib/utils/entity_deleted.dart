import '../network/json_utils.dart';

const String deletedEntityDisplayText = 'deleted';

bool entityDeleted(Object? raw, {Object? fallback}) {
  return asBool(raw, fallback: asBool(fallback));
}

String deletedAwareIdLabel(String value, {required bool deleted}) {
  if (deleted) return deletedEntityDisplayText;
  final trimmed = value.trim();
  return trimmed.isEmpty ? '-' : trimmed;
}
