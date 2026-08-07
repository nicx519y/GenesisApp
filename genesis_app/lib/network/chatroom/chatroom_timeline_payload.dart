import 'dart:convert';

const String chatroomUserEnterLocationSenderType = 'user_enter_location';
const String chatroomStoryEventsSenderType = 'story_events';
const String chatroomCharactersMovedSenderType = 'characters_moved';

const int chatroomMaxFrameBytes = 1024 * 1024;
const int chatroomMaxCollectionItems = 100;
const int chatroomMaxStringCodeUnits = 32 * 1024;

const Set<String> chatroomTimelinePayloadSenderTypes = <String>{
  chatroomUserEnterLocationSenderType,
  chatroomStoryEventsSenderType,
  chatroomCharactersMovedSenderType,
};

bool isChatroomTimelinePayloadSenderType(Object? value) {
  return chatroomTimelinePayloadSenderTypes.contains(_normalizedType(value));
}

bool isChatroomLocationSupplementalSenderType(Object? value) {
  final normalized = _normalizedType(value);
  return normalized == 'tick' ||
      chatroomTimelinePayloadSenderTypes.contains(normalized);
}

bool isChatroomMessageIdOrderedSupplemental(
  Object? value, {
  required int locationMessageId,
}) {
  final normalized = _normalizedType(value);
  if (normalized == chatroomUserEnterLocationSenderType &&
      locationMessageId > 0) {
    return false;
  }
  return isChatroomLocationSupplementalSenderType(normalized);
}

sealed class ChatroomTimelinePayload {
  const ChatroomTimelinePayload();

  String get senderType;

  Map<String, Object?> toJson();
}

class ChatroomUserEnterLocationPayload extends ChatroomTimelinePayload {
  const ChatroomUserEnterLocationPayload({
    required this.charId,
    required this.toLocationId,
    required this.text,
  });

  final String charId;
  final String toLocationId;
  final String text;

  @override
  String get senderType => chatroomUserEnterLocationSenderType;

  factory ChatroomUserEnterLocationPayload.fromJson(Map<String, Object?> json) {
    return ChatroomUserEnterLocationPayload(
      charId: _requiredString(json, 'char_id', nonEmpty: true),
      toLocationId: _requiredString(json, 'to_location_id', nonEmpty: true),
      text: _requiredString(json, 'text'),
    );
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'char_id': charId,
    'to_location_id': toLocationId,
    'text': text,
  };
}

class ChatroomStoryEventsPayload extends ChatroomTimelinePayload {
  const ChatroomStoryEventsPayload({
    required this.locationId,
    required this.locationName,
    required this.paragraphs,
  });

  final String locationId;
  final String locationName;
  final List<ChatroomStoryEventParagraph> paragraphs;

  @override
  String get senderType => chatroomStoryEventsSenderType;

  factory ChatroomStoryEventsPayload.fromJson(Map<String, Object?> json) {
    final locationId = _requiredString(json, 'location_id', nonEmpty: true);
    final rawLocationName = json['location_name'];
    final locationName = rawLocationName == null
        ? ''
        : _requiredString(json, 'location_name');
    if (!json.containsKey('paragraphs')) {
      return ChatroomStoryEventsPayload(
        locationId: locationId,
        locationName: locationName,
        paragraphs: <ChatroomStoryEventParagraph>[
          ChatroomStoryEventParagraph.fromJson(json),
        ],
      );
    }
    return ChatroomStoryEventsPayload(
      locationId: locationId,
      locationName: locationName,
      paragraphs: _requiredList(json, 'paragraphs')
          .map(
            (item) => ChatroomStoryEventParagraph.fromJson(
              _requiredJsonMap(item, field: 'paragraphs[]'),
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'location_id': locationId,
    'location_name': locationName,
    'paragraphs': paragraphs
        .map((paragraph) => paragraph.toJson())
        .toList(growable: false),
  };
}

class ChatroomStoryEventParagraph {
  const ChatroomStoryEventParagraph({
    required this.timestamp,
    required this.visibility,
    required this.visibleTo,
    required this.text,
    required this.clue,
  });

  final String timestamp;
  final String visibility;
  final List<String> visibleTo;
  final String text;
  final String clue;

  factory ChatroomStoryEventParagraph.fromJson(Map<String, Object?> json) {
    final visibility = _requiredString(
      json,
      'visibility',
      nonEmpty: true,
    ).trim().toLowerCase();
    if (visibility != 'public' && visibility != 'char_only') {
      throw FormatException(
        'story_events paragraphs[].visibility must be public or char_only',
      );
    }
    final rawVisibleTo = json['visible_to'];
    final visibleTo = rawVisibleTo == null && visibility == 'public'
        ? const <String>[]
        : _requiredStringList(json, 'visible_to');
    if (visibility == 'char_only' && visibleTo.isEmpty) {
      throw const FormatException(
        'story_events char_only paragraphs require visible_to',
      );
    }
    return ChatroomStoryEventParagraph(
      timestamp: _requiredString(json, 'timestamp'),
      visibility: visibility,
      visibleTo: visibleTo,
      text: _requiredString(json, 'text'),
      clue: _requiredString(json, 'clue'),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'timestamp': timestamp,
    'visibility': visibility,
    'visible_to': visibleTo,
    'text': text,
    'clue': clue,
  };
}

class ChatroomCharactersMovedPayload extends ChatroomTimelinePayload {
  const ChatroomCharactersMovedPayload({required this.movements});

  final List<ChatroomCharacterMovement> movements;

  @override
  String get senderType => chatroomCharactersMovedSenderType;

  factory ChatroomCharactersMovedPayload.fromJson(Map<String, Object?> json) {
    return ChatroomCharactersMovedPayload(
      movements: _requiredList(json, 'movements')
          .map(
            (item) => ChatroomCharacterMovement.fromJson(
              _requiredJsonMap(item, field: 'movements[]'),
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'movements': movements
        .map((movement) => movement.toJson())
        .toList(growable: false),
  };
}

class ChatroomCharacterMovement {
  const ChatroomCharacterMovement({
    required this.charId,
    required this.toLocationId,
  });

  final String charId;
  final String toLocationId;

  factory ChatroomCharacterMovement.fromJson(Map<String, Object?> json) {
    return ChatroomCharacterMovement(
      charId: _requiredString(json, 'char_id', nonEmpty: true),
      toLocationId: _requiredString(json, 'to_loc_id', nonEmpty: true),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'char_id': charId,
    'to_loc_id': toLocationId,
  };
}

ChatroomTimelinePayload decodeChatroomTimelinePayload({
  required Object? senderType,
  required Object? rawPayload,
}) {
  final normalizedSenderType = _normalizedType(senderType);
  if (!chatroomTimelinePayloadSenderTypes.contains(normalizedSenderType)) {
    throw FormatException(
      'Unsupported chatroom timeline sender_type: $normalizedSenderType',
    );
  }
  final payload = normalizedSenderType == chatroomCharactersMovedSenderType
      ? _decodeCharactersMovedPayloadMap(rawPayload)
      : _decodePayloadMap(rawPayload);
  return switch (normalizedSenderType) {
    chatroomUserEnterLocationSenderType =>
      ChatroomUserEnterLocationPayload.fromJson(payload),
    chatroomStoryEventsSenderType => ChatroomStoryEventsPayload.fromJson(
      payload,
    ),
    chatroomCharactersMovedSenderType =>
      ChatroomCharactersMovedPayload.fromJson(payload),
    _ => throw FormatException(
      'Unsupported chatroom timeline sender_type: $normalizedSenderType',
    ),
  };
}

ChatroomTimelinePayload? tryDecodeChatroomTimelinePayload({
  required Object? senderType,
  required Object? rawPayload,
}) {
  try {
    return decodeChatroomTimelinePayload(
      senderType: senderType,
      rawPayload: rawPayload,
    );
  } catch (_) {
    return null;
  }
}

String encodeChatroomTimelinePayload(ChatroomTimelinePayload payload) {
  return jsonEncode(payload.toJson());
}

bool isChatroomFrameOversized(String value) {
  var byteCount = 0;
  for (var index = 0; index < value.length; index += 1) {
    final codeUnit = value.codeUnitAt(index);
    if (codeUnit <= 0x7f) {
      byteCount += 1;
    } else if (codeUnit <= 0x7ff) {
      byteCount += 2;
    } else if (codeUnit >= 0xd800 &&
        codeUnit <= 0xdbff &&
        index + 1 < value.length) {
      final nextCodeUnit = value.codeUnitAt(index + 1);
      if (nextCodeUnit >= 0xdc00 && nextCodeUnit <= 0xdfff) {
        byteCount += 4;
        index += 1;
      } else {
        byteCount += 3;
      }
    } else {
      byteCount += 3;
    }
    if (byteCount > chatroomMaxFrameBytes) return true;
  }
  return false;
}

void validateChatroomPayloadLimits(Object? value, {String field = 'payload'}) {
  final pending = <({Object? value, String field})>[
    (value: value, field: field),
  ];
  while (pending.isNotEmpty) {
    final current = pending.removeLast();
    final currentValue = current.value;
    if (currentValue is String) {
      if (currentValue.length > chatroomMaxStringCodeUnits) {
        throw FormatException(
          '${current.field} exceeds $chatroomMaxStringCodeUnits code units',
        );
      }
      continue;
    }
    if (currentValue is List) {
      if (currentValue.length > chatroomMaxCollectionItems) {
        throw FormatException(
          '${current.field} exceeds $chatroomMaxCollectionItems items',
        );
      }
      for (var index = 0; index < currentValue.length; index += 1) {
        pending.add((
          value: currentValue[index],
          field: '${current.field}[$index]',
        ));
      }
      continue;
    }
    if (currentValue is Map) {
      for (final entry in currentValue.entries) {
        final key = entry.key.toString();
        if (key.length > chatroomMaxStringCodeUnits) {
          throw FormatException(
            '${current.field} key exceeds '
            '$chatroomMaxStringCodeUnits code units',
          );
        }
        pending.add((value: entry.value, field: '${current.field}.$key'));
      }
    }
  }
}

Map<String, Object?> _decodePayloadMap(Object? rawPayload) {
  return _requiredJsonMap(_decodePayload(rawPayload), field: 'payload');
}

Map<String, Object?> _decodeCharactersMovedPayloadMap(Object? rawPayload) {
  final decoded = _decodePayload(rawPayload);
  if (decoded is List) {
    return <String, Object?>{'movements': List<Object?>.from(decoded)};
  }
  return _requiredJsonMap(decoded, field: 'payload');
}

Object? _decodePayload(Object? rawPayload) {
  Object? decoded = rawPayload;
  if (rawPayload is String) {
    if (isChatroomFrameOversized(rawPayload)) {
      throw const FormatException(
        'Chatroom timeline content exceeds the maximum payload size',
      );
    }
    try {
      decoded = jsonDecode(rawPayload);
    } on FormatException catch (error) {
      throw FormatException(
        'Chatroom timeline content is not valid JSON',
        rawPayload,
        error.offset,
      );
    }
  }
  validateChatroomPayloadLimits(decoded);
  return decoded;
}

Map<String, Object?> _requiredJsonMap(Object? value, {required String field}) {
  if (value is! Map) {
    throw FormatException('$field must be a JSON object');
  }
  return value.map((key, value) => MapEntry('$key', value));
}

List<Object?> _requiredList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List) throw FormatException('$key must be a JSON array');
  if (value.length > chatroomMaxCollectionItems) {
    throw FormatException('$key exceeds $chatroomMaxCollectionItems items');
  }
  return List<Object?>.from(value);
}

List<String> _requiredStringList(Map<String, Object?> json, String key) {
  final raw = _requiredList(json, key);
  return raw
      .map((value) {
        if (value is! String || value.trim().isEmpty) {
          throw FormatException('$key must contain non-empty strings');
        }
        return value;
      })
      .toList(growable: false);
}

String _requiredString(
  Map<String, Object?> json,
  String key, {
  bool nonEmpty = false,
}) {
  final value = json[key];
  if (value is! String) throw FormatException('$key must be a string');
  if (value.length > chatroomMaxStringCodeUnits) {
    throw FormatException(
      '$key exceeds $chatroomMaxStringCodeUnits code units',
    );
  }
  if (nonEmpty && value.trim().isEmpty) {
    throw FormatException('$key must not be empty');
  }
  return value;
}

String _normalizedType(Object? value) {
  return value?.toString().trim().toLowerCase() ?? '';
}
