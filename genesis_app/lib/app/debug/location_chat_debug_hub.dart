import 'package:flutter/foundation.dart';

const bool _locationChatDebugFlag = bool.fromEnvironment(
  'GENESIS_LOCATION_CHAT_DEBUG',
  defaultValue: false,
);

class LocationChatDebugHub {
  const LocationChatDebugHub._();

  static int _nextCursor = 1;
  static final List<Map<String, Object?>> _events = <Map<String, Object?>>[];
  static final Map<String, Map<String, Object?>> _snapshots =
      <String, Map<String, Object?>>{
        'world': <String, Object?>{},
        'storage': <String, Object?>{},
        'service': <String, Object?>{},
        'panel': <String, Object?>{},
      };

  static bool get available => !kReleaseMode;

  static bool get enabled => available && _locationChatDebugFlag;

  static Map<String, Object?> snapshot() {
    return <String, Object?>{
      'available': available,
      'enabled': enabled,
      'nextCursor': _nextCursor,
      'events': List<Object?>.unmodifiable(_events),
      'snapshots': _deepCopyMap(_snapshots),
    };
  }

  static Map<String, Object?> eventsAfter(int cursor, {int limit = 100}) {
    final resolvedLimit = limit <= 0 ? 100 : limit;
    final events = _events
        .where((event) => _asInt(event['cursor']) > cursor)
        .take(resolvedLimit)
        .map(_deepCopyMap)
        .toList(growable: false);
    final pageCursor = events.isEmpty ? cursor : _asInt(events.last['cursor']);
    return <String, Object?>{
      'available': available,
      'enabled': enabled,
      'nextCursor': pageCursor,
      'latestCursor': _nextCursor - 1,
      'events': events,
    };
  }

  static void clear() {
    _events.clear();
    for (final layer in _snapshots.values) {
      layer.clear();
    }
    _nextCursor = 1;
  }

  static void record({
    required String source,
    required String action,
    String worldId = '',
    String locationId = '',
    Map<String, Object?> details = const <String, Object?>{},
    String snapshotKey = '',
    Map<String, Object?>? snapshot,
  }) {
    if (!enabled) return;
    _recordUnsafe(
      source: source,
      action: action,
      worldId: worldId,
      locationId: locationId,
      details: details,
      snapshotKey: snapshotKey,
      snapshot: snapshot,
    );
  }

  @visibleForTesting
  static void recordForTesting({
    required String source,
    required String action,
    String worldId = '',
    String locationId = '',
    Map<String, Object?> details = const <String, Object?>{},
    String snapshotKey = '',
    Map<String, Object?>? snapshot,
  }) {
    _recordUnsafe(
      source: source,
      action: action,
      worldId: worldId,
      locationId: locationId,
      details: details,
      snapshotKey: snapshotKey,
      snapshot: snapshot,
    );
  }

  static void _recordUnsafe({
    required String source,
    required String action,
    required String worldId,
    required String locationId,
    required Map<String, Object?> details,
    required String snapshotKey,
    required Map<String, Object?>? snapshot,
  }) {
    final normalizedSource = source.trim().isEmpty ? 'unknown' : source.trim();
    final normalizedAction = action.trim().isEmpty ? 'event' : action.trim();
    final event = <String, Object?>{
      'cursor': _nextCursor++,
      'timestamp': DateTime.now().toIso8601String(),
      'source': normalizedSource,
      'action': normalizedAction,
      if (worldId.trim().isNotEmpty) 'worldId': worldId.trim(),
      if (locationId.trim().isNotEmpty) 'locationId': locationId.trim(),
      'details': _sanitizeMap(details),
    };
    _events.add(event);
    final key = snapshotKey.trim();
    if (key.isNotEmpty && snapshot != null) {
      final layer = _snapshots.putIfAbsent(
        normalizedSource,
        () => <String, Object?>{},
      );
      layer[key] = _sanitizeMap(<String, Object?>{
        ...snapshot,
        'updatedAt': event['timestamp'],
      });
    }
  }

  @visibleForTesting
  static void resetForTesting() {
    clear();
  }

  static Map<String, Object?> _sanitizeMap(Map<String, Object?> input) {
    return <String, Object?>{
      for (final entry in input.entries)
        entry.key: _sanitizeValue(entry.key, entry.value),
    };
  }

  static Object? _sanitizeValue(String key, Object? value) {
    final lowerKey = key.toLowerCase();
    if (lowerKey.contains('token') ||
        lowerKey.contains('authorization') ||
        lowerKey.contains('password') ||
        lowerKey.contains('secret')) {
      return _redactedValue(value);
    }
    if (value == null || value is num || value is bool) return value;
    if (value is DateTime) return value.toIso8601String();
    if (value is String) return _truncate(value);
    if (value is Map) {
      return <String, Object?>{
        for (final entry in value.entries)
          '${entry.key}': _sanitizeValue('${entry.key}', entry.value),
      };
    }
    if (value is Iterable) {
      return value
          .map((item) => _sanitizeValue('', item))
          .toList(growable: false);
    }
    return _truncate('$value');
  }

  static String _truncate(String value) {
    const maxLength = 240;
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength)}...';
  }

  static String _redactedValue(Object? value) {
    final text = '$value';
    if (text.trim().isEmpty || text == 'null') return '';
    if (text.length <= 8) return '****';
    return '${text.substring(0, 4)}...${text.substring(text.length - 4)}';
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  static Map<String, Object?> _deepCopyMap(Map<dynamic, dynamic> input) {
    return <String, Object?>{
      for (final entry in input.entries)
        '${entry.key}': _sanitizeValue('${entry.key}', entry.value),
    };
  }
}
