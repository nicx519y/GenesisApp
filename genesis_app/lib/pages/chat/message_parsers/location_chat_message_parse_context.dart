import '../../../components/chat/shared/chat_ui.dart';
import '../../../network/chatroom/world_chatroom_service.dart';

typedef LocationChatMessageResolver<T> =
    T Function(WorldChatroomMessage message);
typedef LocationChatIdentityNameResolver = String Function(String id);

class LocationChatMessageParseContext {
  const LocationChatMessageParseContext({
    required this.isMine,
    required this.senderName,
    required this.avatarUrl,
    required this.isPlayerControlledRole,
    required this.characterName,
    required this.locationName,
    required this.roleName,
    this.hasCachedTimelinePayload = false,
    this.cachedTimelinePayload,
  });

  final LocationChatMessageResolver<bool> isMine;
  final LocationChatMessageResolver<String> senderName;
  final LocationChatMessageResolver<String> avatarUrl;
  final LocationChatMessageResolver<bool> isPlayerControlledRole;
  final LocationChatIdentityNameResolver characterName;
  final LocationChatIdentityNameResolver locationName;
  final LocationChatIdentityNameResolver roleName;
  final bool hasCachedTimelinePayload;
  final ChatTimelinePayloadVm? cachedTimelinePayload;

  LocationChatMessageParseContext withTimelineCache({
    required bool hasCachedTimelinePayload,
    required ChatTimelinePayloadVm? cachedTimelinePayload,
  }) {
    return LocationChatMessageParseContext(
      isMine: isMine,
      senderName: senderName,
      avatarUrl: avatarUrl,
      isPlayerControlledRole: isPlayerControlledRole,
      characterName: characterName,
      locationName: locationName,
      roleName: roleName,
      hasCachedTimelinePayload: hasCachedTimelinePayload,
      cachedTimelinePayload: cachedTimelinePayload,
    );
  }
}
