import '../../../components/chat/shared/chat_ui.dart';
import '../../../network/chatroom/chatroom_timeline_payload.dart';
import '../../../network/chatroom/world_chatroom_service.dart';
import '../../../utils/genesis_ugc_text.dart';
import 'location_chat_message_parse_context.dart';
import 'location_chat_message_parse_support.dart';
import 'location_chat_message_parser.dart';
import 'location_chat_parsed_message.dart';

class UserEnterLocationMessageParser implements LocationChatMessageParser {
  const UserEnterLocationMessageParser();

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
      senderType: chatroomUserEnterLocationSenderType,
      text: locationChatTimelineCopyText(timelinePayload),
      timelinePayload: timelinePayload,
    );
  }

  ChatUserEnterLocationPayloadVm? _timelinePayload(
    WorldChatroomMessage message,
    LocationChatMessageParseContext context,
  ) {
    if (context.hasCachedTimelinePayload) {
      final cached = context.cachedTimelinePayload;
      return cached is ChatUserEnterLocationPayloadVm ? cached : null;
    }
    final payload = message.timelinePayload;
    if (payload is! ChatroomUserEnterLocationPayload) return null;
    return ChatUserEnterLocationPayloadVm(
      characterId: payload.charId.trim(),
      toLocationId: payload.toLocationId.trim(),
      text: normalizeGenesisUgcTextForDisplay(payload.text),
    );
  }
}
