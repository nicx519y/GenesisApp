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
    final payloadLocationId = payload.locationId.trim();
    final currentLocationId = context.currentLocationId.trim();
    if (currentLocationId.isNotEmpty &&
        payloadLocationId != currentLocationId) {
      return null;
    }
    final payloadLocationName = normalizeGenesisUgcTextForDisplay(
      payload.locationName,
    ).trim();
    final resolvedLocationName = payloadLocationName.isNotEmpty
        ? payloadLocationName
        : context.locationName(payloadLocationId);
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
          roleIsAi: context.roleIsAi,
          roleAvatarUrl: context.roleAvatarUrl,
          locationId: payloadLocationId,
          locationName: resolvedLocationName,
        ),
      );
    }
    if (paragraphs.isEmpty) return null;
    return ChatStoryEventsPayloadVm(
      locationId: payloadLocationId,
      locationName: resolvedLocationName,
      paragraphs: List<ChatStoryEventParagraphVm>.unmodifiable(paragraphs),
    );
  }
}

ChatStoryEventParagraphVm parseLocationChatStoryEventParagraph(
  ChatroomStoryEventParagraph paragraph, {
  required String Function(String id) roleName,
  required bool? Function(String id) roleIsAi,
  String Function(String id)? roleAvatarUrl,
  String locationId = '',
  String locationName = '',
}) {
  final visibility = paragraph.visibility.trim().toLowerCase();
  String visibilityLabel;
  final visibleRoles = <ChatStoryEventVisibleRoleVm>[];
  if (visibility == 'public') {
    visibilityLabel = 'public';
  } else if (visibility == 'char_only') {
    final matchingNames = <String>[];
    final seenNames = <String>{};
    for (final visibleId in paragraph.visibleTo) {
      final name = roleName(visibleId).trim();
      if (name.isEmpty || !seenNames.add(name)) continue;
      matchingNames.add(name);
      visibleRoles.add(
        ChatStoryEventVisibleRoleVm(
          roleId: visibleId.trim(),
          name: name,
          isAi: roleIsAi(visibleId) ?? false,
          avatarUrl: roleAvatarUrl?.call(visibleId) ?? '',
        ),
      );
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
    visibleRoles: List<ChatStoryEventVisibleRoleVm>.unmodifiable(visibleRoles),
    locationId: locationId,
    locationName: locationName,
  );
}
