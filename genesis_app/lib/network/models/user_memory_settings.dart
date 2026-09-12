class UserMemorySettings {
  const UserMemorySettings({
    required this.memoryTokens,
    required this.minMemoryTokens,
    required this.maxMemoryTokens,
    this.worldId,
    this.memoryUsedTokens,
  });

  factory UserMemorySettings.fromJson(Map<String, dynamic> json) {
    return UserMemorySettings(
      memoryTokens: _requireInteger(json, 'memory_tokens'),
      minMemoryTokens: _requireInteger(json, 'min_memory_tokens'),
      maxMemoryTokens: _requireInteger(json, 'max_memory_tokens'),
      worldId: _optionalString(json, 'world_id'),
      memoryUsedTokens: json.containsKey('memory_used_tokens')
          ? _requireInteger(json, 'memory_used_tokens')
          : null,
    );
  }

  final int memoryTokens;
  final int minMemoryTokens;
  final int maxMemoryTokens;
  final String? worldId;
  final int? memoryUsedTokens;
}

int _requireInteger(Map<String, dynamic> json, String fieldName) {
  final value = json[fieldName];
  if (value is int) return value;
  throw FormatException('$fieldName must be an integer');
}

String? _optionalString(Map<String, dynamic> json, String fieldName) {
  if (!json.containsKey(fieldName)) return null;
  final value = json[fieldName];
  if (value is String) return value.trim();
  throw FormatException('$fieldName must be a string');
}
