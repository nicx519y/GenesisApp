part of 'chat_ui_library.dart';

class ChatMessageVm {
  ChatMessageVm({
    required this.localId,
    this.clientMsgId = '',
    this.globalMessageId = 0,
    this.messageId,
    this.locationMessageId = 0,
    this.roundId = '',
    this.tickNo = 0,
    this.subTickNo = 0,
    required this.senderId,
    required this.senderName,
    this.avatarUrl = '',
    this.imageUrl = '',
    this.timelinePayload,
    this.isPlayerControlledRole = false,
    required this.text,
    this.currentTime = '',
    required this.isMe,
    required this.status,
    this.senderType = 'user',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ChatMessageVm.system(String text) {
    return ChatMessageVm(
      localId: 'system-${DateTime.now().microsecondsSinceEpoch}',
      senderId: '',
      senderName: '',
      text: text,
      isMe: false,
      status: 'system',
      senderType: 'system',
    );
  }

  final String localId;
  String clientMsgId;
  int globalMessageId;
  int? messageId;
  int locationMessageId;
  String roundId;
  int tickNo;
  int subTickNo;
  final String senderId;
  String senderName;
  String avatarUrl;
  String imageUrl;
  ChatTimelinePayloadVm? timelinePayload;
  bool isPlayerControlledRole;
  String text;
  String currentTime;
  bool isMe;
  String status;
  final String senderType;
  String? error;
  final DateTime createdAt;

  bool get isSystem => senderType == 'system' || isNarrator || isTick;

  bool get isNarrator => senderType == 'narrator';

  bool get isTick => senderType == 'tick';

  bool get isImage =>
      senderType == 'image' ||
      senderType == 'nar_pic' ||
      imageUrl.trim().isNotEmpty;

  bool get isUserEnterLocation =>
      timelinePayload is ChatUserEnterLocationPayloadVm;

  bool get isStoryEvents => timelinePayload is ChatStoryEventsPayloadVm;

  bool get isCharactersMoved => timelinePayload is ChatCharactersMovedPayloadVm;

  bool get isTimelineEvent =>
      isUserEnterLocation || isStoryEvents || isCharactersMoved;
}

sealed class ChatTimelinePayloadVm {
  const ChatTimelinePayloadVm();
}

class ChatUserEnterLocationPayloadVm extends ChatTimelinePayloadVm {
  const ChatUserEnterLocationPayloadVm({
    required this.characterId,
    required this.toLocationId,
    required this.text,
  });

  final String characterId;
  final String toLocationId;
  final String text;

  @override
  bool operator ==(Object other) {
    return other is ChatUserEnterLocationPayloadVm &&
        other.characterId == characterId &&
        other.toLocationId == toLocationId &&
        other.text == text;
  }

  @override
  int get hashCode => Object.hash(characterId, toLocationId, text);
}

class ChatStoryEventsPayloadVm extends ChatTimelinePayloadVm {
  const ChatStoryEventsPayloadVm({
    required this.locationId,
    required this.locationName,
    required this.paragraphs,
  });

  final String locationId;
  final String locationName;
  final List<ChatStoryEventParagraphVm> paragraphs;

  @override
  bool operator ==(Object other) {
    return other is ChatStoryEventsPayloadVm &&
        other.locationId == locationId &&
        other.locationName == locationName &&
        listEquals(other.paragraphs, paragraphs);
  }

  @override
  int get hashCode =>
      Object.hash(locationId, locationName, Object.hashAll(paragraphs));
}

class ChatStoryEventParagraphVm {
  const ChatStoryEventParagraphVm({
    required this.timestamp,
    required this.text,
    required this.clue,
    required this.visibilityLabel,
    this.visibleRoles = const <ChatStoryEventVisibleRoleVm>[],
    this.locationId = '',
    this.locationName = '',
  });

  final String timestamp;
  final String text;
  final String clue;
  final String visibilityLabel;
  final List<ChatStoryEventVisibleRoleVm> visibleRoles;
  final String locationId;
  final String locationName;

  @override
  bool operator ==(Object other) {
    return other is ChatStoryEventParagraphVm &&
        other.timestamp == timestamp &&
        other.text == text &&
        other.clue == clue &&
        other.visibilityLabel == visibilityLabel &&
        listEquals(other.visibleRoles, visibleRoles) &&
        other.locationId == locationId &&
        other.locationName == locationName;
  }

  @override
  int get hashCode => Object.hash(
    timestamp,
    text,
    clue,
    visibilityLabel,
    Object.hashAll(visibleRoles),
    locationId,
    locationName,
  );
}

class ChatStoryEventVisibleRoleVm {
  const ChatStoryEventVisibleRoleVm({
    required this.roleId,
    required this.name,
    required this.isAi,
  });

  final String roleId;
  final String name;
  final bool isAi;

  @override
  bool operator ==(Object other) {
    return other is ChatStoryEventVisibleRoleVm &&
        other.roleId == roleId &&
        other.name == name &&
        other.isAi == isAi;
  }

  @override
  int get hashCode => Object.hash(roleId, name, isAi);
}

class ChatCharactersMovedPayloadVm extends ChatTimelinePayloadVm {
  const ChatCharactersMovedPayloadVm({required this.movements});

  final List<ChatCharacterMovementVm> movements;

  @override
  bool operator ==(Object other) {
    return other is ChatCharactersMovedPayloadVm &&
        listEquals(other.movements, movements);
  }

  @override
  int get hashCode => Object.hashAll(movements);
}

class ChatCharacterMovementVm {
  const ChatCharacterMovementVm({
    required this.characterId,
    required this.characterName,
    required this.toLocationId,
    required this.toLocationName,
    this.isDestinationCurrentLocation = false,
  });

  final String characterId;
  final String characterName;
  final String toLocationId;
  final String toLocationName;
  final bool isDestinationCurrentLocation;

  @override
  bool operator ==(Object other) {
    return other is ChatCharacterMovementVm &&
        other.characterId == characterId &&
        other.characterName == characterName &&
        other.toLocationId == toLocationId &&
        other.toLocationName == toLocationName &&
        other.isDestinationCurrentLocation == isDestinationCurrentLocation;
  }

  @override
  int get hashCode => Object.hash(
    characterId,
    characterName,
    toLocationId,
    toLocationName,
    isDestinationCurrentLocation,
  );
}

typedef ChatMessageLongPressStart =
    void Function(
      BuildContext context,
      ChatMessageVm message,
      LongPressStartDetails details,
    );

typedef ChatMessageTap = void Function(ChatMessageVm message);

typedef ChatCharacterMovementTap =
    void Function(ChatCharacterMovementVm movement);
