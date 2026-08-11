import '../../../components/chat/shared/chat_ui.dart';
import '../../../network/chatroom/chatroom_timeline_payload.dart';
import '../../../network/chatroom/world_chatroom_service.dart';
import 'location_chat_message_parse_context.dart';
import 'location_chat_message_parse_support.dart';
import 'location_chat_message_parser.dart';
import 'location_chat_parsed_message.dart';

class CharactersMovedMessageParser implements LocationChatMessageParser {
  const CharactersMovedMessageParser();

  @override
  LocationChatParsedMessage? parse(
    WorldChatroomMessage message,
    LocationChatMessageParseContext context,
  ) {
    final timelinePayload = _timelinePayload(message, context);
    if (timelinePayload == null) return null;
    return buildLocationChatParsedMessage(
      message: message,
      context: context,
      senderType: chatroomCharactersMovedSenderType,
      text: locationChatTimelineCopyText(timelinePayload),
      timelinePayload: timelinePayload,
    );
  }

  ChatCharactersMovedPayloadVm? _timelinePayload(
    WorldChatroomMessage message,
    LocationChatMessageParseContext context,
  ) {
    if (context.hasCachedTimelinePayload) {
      final cached = context.cachedTimelinePayload;
      return cached is ChatCharactersMovedPayloadVm ? cached : null;
    }
    final payload = message.timelinePayload;
    if (payload is! ChatroomCharactersMovedPayload) return null;
    if (payload.movements.isEmpty ||
        payload.movements.length > chatroomMaxCollectionItems) {
      return null;
    }
    if (payload.movements.any(
      (movement) =>
          !locationChatTimelineStringIsSafe(movement.charId) ||
          !locationChatTimelineStringIsSafe(movement.toLocationId),
    )) {
      return null;
    }
    final movements = payload.movements
        .map(
          (movement) => ChatCharacterMovementVm(
            characterId: movement.charId.trim(),
            characterName: context.characterName(movement.charId),
            toLocationId: movement.toLocationId.trim(),
            toLocationName: context.locationName(movement.toLocationId),
            isDestinationCurrentLocation:
                context.currentLocationId.trim().isNotEmpty &&
                movement.toLocationId.trim() ==
                    context.currentLocationId.trim(),
          ),
        )
        .toList(growable: false);
    return ChatCharactersMovedPayloadVm(movements: movements);
  }
}
