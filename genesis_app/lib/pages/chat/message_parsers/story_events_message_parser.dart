import '../../../components/chat/shared/chat_ui.dart';
import '../../../network/chatroom/chatroom_timeline_payload.dart';
import '../../../network/chatroom/world_chatroom_service.dart';
import '../../../utils/genesis_ugc_text.dart';
import 'location_chat_message_parse_context.dart';
import 'location_chat_message_parse_support.dart';
import 'location_chat_message_parser.dart';
import 'location_chat_parsed_message.dart';

class StoryEventsMessageParser implements LocationChatMessageParser {
  const StoryEventsMessageParser();

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
      senderType: chatroomStoryEventsSenderType,
      text: locationChatTimelineCopyText(timelinePayload),
      timelinePayload: timelinePayload,
    );
  }

  ChatStoryEventsPayloadVm? _timelinePayload(
    WorldChatroomMessage message,
    LocationChatMessageParseContext context,
  ) {
    if (context.hasCachedTimelinePayload) {
      final cached = context.cachedTimelinePayload;
      return cached is ChatStoryEventsPayloadVm ? cached : null;
    }
    final payload = message.timelinePayload;
    if (payload is! ChatroomStoryEventsPayload) return null;
    if (!locationChatTimelineStringIsSafe(payload.locationId) ||
        !locationChatTimelineStringIsSafe(payload.locationName) ||
        payload.paragraphs.length > chatroomMaxCollectionItems) {
      return null;
    }
    final paragraphs = <ChatStoryEventParagraphVm>[];
    for (final paragraph in payload.paragraphs) {
      if (!locationChatTimelineStringIsSafe(paragraph.timestamp) ||
          !locationChatTimelineStringIsSafe(paragraph.visibility) ||
          !locationChatTimelineStringIsSafe(paragraph.text) ||
          !locationChatTimelineStringIsSafe(paragraph.clue) ||
          paragraph.visibleTo.length > chatroomMaxCollectionItems ||
          paragraph.visibleTo.any(
            (value) => !locationChatTimelineStringIsSafe(value),
          )) {
        return null;
      }
      paragraphs.add(
        parseLocationChatStoryEventParagraph(
          paragraph,
          roleName: context.roleName,
        ),
      );
    }
    if (paragraphs.isEmpty) return null;
    final payloadLocationName = normalizeGenesisUgcTextForDisplay(
      payload.locationName,
    ).trim();
    return ChatStoryEventsPayloadVm(
      locationId: payload.locationId.trim(),
      locationName: payloadLocationName.isNotEmpty
          ? payloadLocationName
          : context.locationName(payload.locationId),
      paragraphs: List<ChatStoryEventParagraphVm>.unmodifiable(paragraphs),
    );
  }
}

ChatStoryEventParagraphVm parseLocationChatStoryEventParagraph(
  ChatroomStoryEventParagraph paragraph, {
  required String Function(String id) roleName,
}) {
  final visibility = paragraph.visibility.trim().toLowerCase();
  String visibilityLabel;
  if (visibility == 'public') {
    visibilityLabel = 'public';
  } else if (visibility == 'char_only') {
    final matchingNames = <String>[];
    final seenNames = <String>{};
    for (final visibleId in paragraph.visibleTo) {
      final name = roleName(visibleId).trim();
      if (name.isEmpty || !seenNames.add(name)) continue;
      matchingNames.add(name);
    }
    visibilityLabel = matchingNames.join(', ');
  } else {
    visibilityLabel = '';
  }
  return ChatStoryEventParagraphVm(
    timestamp: normalizeGenesisUgcTextForDisplay(paragraph.timestamp),
    text: normalizeGenesisUgcTextForDisplay(paragraph.text),
    clue: normalizeGenesisUgcTextForDisplay(paragraph.clue),
    visibilityLabel: normalizeGenesisUgcTextForDisplay(visibilityLabel),
  );
}
