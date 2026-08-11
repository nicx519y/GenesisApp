import '../../../components/chat/shared/chat_ui.dart';
import '../../../network/chatroom/world_chatroom_service.dart';

typedef LocationChatMessageResolver<T> =
    T Function(WorldChatroomMessage message);
typedef LocationChatIdentityNameResolver = String Function(String id);
typedef LocationChatIdentityAiResolver = bool? Function(String id);

class LocationChatMessageParseContext {
  const LocationChatMessageParseContext({
    required this.currentLocationId,
    required this.isMine,
    required this.senderName,
    required this.avatarUrl,
    required this.isPlayerControlledRole,
    required this.characterName,
    required this.locationName,
    required this.roleName,
    required this.roleIsAi,
    this.hasCachedTimelinePayload = false,
    this.cachedTimelinePayload,
  });

  final String currentLocationId;
  final LocationChatMessageResolver<bool> isMine;
  final LocationChatMessageResolver<String> senderName;
  final LocationChatMessageResolver<String> avatarUrl;
  final LocationChatMessageResolver<bool> isPlayerControlledRole;
  final LocationChatIdentityNameResolver characterName;
  final LocationChatIdentityNameResolver locationName;
  final LocationChatIdentityNameResolver roleName;
  final LocationChatIdentityAiResolver roleIsAi;
  final bool hasCachedTimelinePayload;
  final ChatTimelinePayloadVm? cachedTimelinePayload;

  LocationChatMessageParseContext withTimelineCache({
    required bool hasCachedTimelinePayload,
    required ChatTimelinePayloadVm? cachedTimelinePayload,
  }) {
    return LocationChatMessageParseContext(
      currentLocationId: currentLocationId,
      isMine: isMine,
      senderName: senderName,
      avatarUrl: avatarUrl,
      isPlayerControlledRole: isPlayerControlledRole,
      characterName: characterName,
      locationName: locationName,
      roleName: roleName,
      roleIsAi: roleIsAi,
      hasCachedTimelinePayload: hasCachedTimelinePayload,
      cachedTimelinePayload: cachedTimelinePayload,
    );
  }
}
