String originDisplayName(String name, {String fallback = ''}) {
  final trimmed = name.trim().isEmpty ? fallback.trim() : name.trim();
  if (trimmed.isEmpty || trimmed.startsWith('#')) return trimmed;
  return '#$trimmed';
}

String formatUidForDisplay(String uid, {String fallback = ''}) {
  final trimmed = uid.trim();
  final value = trimmed.isEmpty ? fallback.trim() : trimmed;
  if (value.startsWith('U_')) return 'u_${value.substring(2)}';
  return value;
}
