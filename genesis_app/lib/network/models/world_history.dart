import 'dart:convert';

/// The world archive has its own contract; IDs and cursors are opaque strings.
class WorldHistoryPage {
  const WorldHistoryPage({
    required this.worldId,
    required this.messages,
    required this.hasMore,
    required this.cursor,
  });
  final String worldId;
  final List<WorldHistoryMessage> messages;
  final bool hasMore;
  final String cursor;

  factory WorldHistoryPage.fromJson(Map<String, dynamic> json) {
    final more = json['has_more'];
    final rows = json['messages'];
    if (more is! bool || rows is! List) {
      throw const FormatException('Invalid world history page');
    }
    final cursor = _string(json, 'cursor');
    if (more == cursor.isEmpty) {
      throw const FormatException('Invalid world history cursor');
    }
    return WorldHistoryPage(
      worldId: _string(json, 'world_id', nonempty: true),
      messages: List.unmodifiable(
        rows.map((row) => WorldHistoryMessage.fromJson(_object(row))),
      ),
      hasMore: more,
      cursor: cursor,
    );
  }

  void validate(String requestedWorld, String? requestCursor) {
    if (worldId != requestedWorld) {
      throw const FormatException('History response World does not match');
    }
    if (hasMore && (cursor.isEmpty || cursor == requestCursor) ||
        !hasMore && cursor.isNotEmpty) {
      throw const FormatException('History cursor did not advance');
    }
  }
}

class WorldHistoryMessage {
  WorldHistoryMessage({
    required this.id,
    required this.type,
    required this.senderId,
    required this.senderName,
    this.userId,
    required this.messageType,
    required this.content,
    required this.minAppVersion,
    required this.currentTime,
    required this.createdAt,
    required this.locationRefs,
  });
  final String id,
      type,
      senderId,
      senderName,
      messageType,
      content,
      currentTime;
  final String? userId;
  final int minAppVersion;
  final DateTime createdAt;
  final List<String> locationRefs;
  // Lazy and owned by the raw page. Metadata updates never decode again.
  late final WorldHistoryTick? tick = type == 'tick'
      ? WorldHistoryTick.tryDecode(content)
      : null;
  late final int contentBytes = utf8.encode(content).length;

  factory WorldHistoryMessage.fromJson(Map<String, dynamic> json) {
    final version = json['min_app_version'];
    final userId = json['user_id'];
    final created = _string(json, 'created_at');
    final date = DateTime.tryParse(created);
    if (version is! int ||
        version < 0 ||
        (userId != null && userId is! String) ||
        date == null ||
        !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(created)) {
      throw const FormatException('Invalid world history message');
    }
    return WorldHistoryMessage(
      id: _string(json, 'global_message_id', nonempty: true),
      type: _string(json, 'type'),
      senderId: _string(json, 'sender_id'),
      senderName: _string(json, 'sender_name'),
      userId: userId as String?,
      messageType: _string(json, 'message_type'),
      content: _string(json, 'content'),
      minAppVersion: version,
      currentTime: _string(json, 'current_time'),
      createdAt: date,
      locationRefs: _strings(json['location_refs'], nullable: false),
    );
  }
}

class WorldHistoryTick {
  WorldHistoryTick._(Map<String, dynamic> json)
    : currentTime = _string(json, 'current_time'),
      global = _string(json, 'global'),
      globalStatus = _objects(json['global_status'], HistoryStatus.fromJson),
      events = _objects(json['story_events'], HistoryStoryEvent.fromJson),
      movements = _objects(json['characters_moved'], HistoryMovement.fromJson);
  final String currentTime, global;
  final List<HistoryStatus> globalStatus;
  final List<HistoryStoryEvent> events;
  final List<HistoryMovement> movements;

  static WorldHistoryTick? tryDecode(String content) {
    try {
      final json = _object(jsonDecode(content));
      // Do not mistake an arbitrary historical JSON object for a Tick.
      if (!json.containsKey('global') ||
          !json.containsKey('current_time') ||
          !json.containsKey('story_events') ||
          !json.containsKey('characters_moved')) {
        return null;
      }
      return WorldHistoryTick._(json);
    } on FormatException {
      return null;
    }
  }
}

class HistoryStatus {
  HistoryStatus.fromJson(Map<String, dynamic> json)
    : owner = _string(json, 'owner'),
      icon = _string(json, 'icon'),
      form = _string(json, 'form'),
      content = _string(json, 'content');
  final String owner, icon, form, content;
}

class HistoryCast {
  HistoryCast.fromJson(Map<String, dynamic> json)
    : id = _string(json, 'id'),
      name = _string(json, 'name');
  final String id, name;
}

class HistoryStoryEvent {
  HistoryStoryEvent.fromJson(Map<String, dynamic> json)
    : locationId = _string(json, 'location_id'),
      timestamp = _string(json, 'timestamp'),
      visibility = _string(json, 'visibility'),
      visibleTo = _strings(json['visible_to']),
      text = _string(json, 'text'),
      clue = _string(json, 'clue'),
      cast = _objects(json['cast'], HistoryCast.fromJson),
      statuses = _objects(json['status'], HistoryStatus.fromJson);
  final String locationId, timestamp, visibility, text, clue;
  final List<String> visibleTo;
  final List<HistoryCast> cast;
  final List<HistoryStatus> statuses;
}

class HistoryMovement {
  HistoryMovement.fromJson(Map<String, dynamic> json)
    : characterId = _string(json, 'char_id'),
      oldLocationId = _string(json, 'old_loc_id'),
      toLocationId = _string(json, 'to_loc_id');
  final String characterId, oldLocationId, toLocationId;
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected history object');
  }
  return value;
}

String _string(Map<String, dynamic> json, String key, {bool nonempty = false}) {
  final value = json[key];
  if (value is! String || nonempty && value.isEmpty) {
    throw FormatException('Invalid history $key');
  }
  return value;
}

List<String> _strings(Object? value, {bool nullable = true}) {
  if (value == null && nullable) return const [];
  if (value is! List || value.any((e) => e is! String)) {
    throw const FormatException('Expected history string array');
  }
  return List<String>.unmodifiable(value);
}

List<T> _objects<T>(Object? value, T Function(Map<String, dynamic>) parse) {
  if (value == null) return const [];
  if (value is! List) throw const FormatException('Expected history array');
  return List.unmodifiable(value.map((e) => parse(_object(e))));
}
