import '../../../components/chat/shared/chat_ui.dart';
import '../../../network/chatroom/chatroom_models.dart';
import '../../../network/chatroom/chatroom_timeline_payload.dart';
import '../../../network/chatroom/world_chatroom_service.dart';
import '../../../utils/genesis_ugc_text.dart';
import 'location_chat_message_parse_context.dart';
import 'location_chat_message_parse_support.dart';
import 'location_chat_message_parser.dart';
import 'location_chat_parsed_message.dart';

class TickMessageParser implements LocationChatMessageParser {
  const TickMessageParser();

  @override
  LocationChatParsedMessage parse(
    WorldChatroomMessage message,
    LocationChatMessageParseContext context,
  ) {
    final payload = message.v2TickPayload;
    if (payload != null) {
      final viewModel = _tickPayloadViewModel(payload, context);
      return buildLocationChatParsedMessage(
        message: message,
        context: context,
        senderType: 'tick',
        text: viewModel.fallbackContent.trim().isNotEmpty
            ? viewModel.fallbackContent
            : viewModel.globalText,
        timelinePayload: viewModel,
        tickNo: payload.tickNo,
        subTickNo: payload.subTickNo,
        currentTime: normalizeGenesisUgcTextForDisplay(payload.currentTime),
      );
    }
    return buildLocationChatParsedMessage(
      message: message,
      context: context,
      senderType: 'tick',
      text: locationChatMessageDisplayText(message),
    );
  }

  ChatTickPayloadVm _tickPayloadViewModel(
    ChatroomV2TickPayload payload,
    LocationChatMessageParseContext context,
  ) {
    final globalText = locationChatTimelineStringIsSafe(payload.globalText)
        ? normalizeGenesisUgcTextForDisplay(payload.globalText)
        : '';
    final fallbackContent =
        locationChatTimelineStringIsSafe(payload.fallbackContent)
        ? normalizeGenesisUgcTextForDisplay(payload.fallbackContent)
        : '';
    return ChatTickPayloadVm(
      globalText: globalText,
      storyEvents: _storyEventsViewModel(payload.storyEvents, context),
      charactersMoved: _charactersMovedViewModel(
        payload.charactersMoved,
        context,
      ),
      fallbackContent: fallbackContent,
    );
  }

  ChatStoryEventsPayloadVm? _storyEventsViewModel(
    List<ChatroomV2StoryEvent> events,
    LocationChatMessageParseContext context,
  ) {
    if (events.isEmpty || events.length > chatroomMaxCollectionItems) {
      return null;
    }
    final paragraphs = <ChatStoryEventParagraphVm>[];
    for (final event in events) {
      final visibleTo = event.visibleTo ?? const <String>[];
      if (!locationChatTimelineStringIsSafe(event.locationId) ||
          !locationChatTimelineStringIsSafe(event.timestamp) ||
          !locationChatTimelineStringIsSafe(event.visibility) ||
          !locationChatTimelineStringIsSafe(event.text) ||
          !locationChatTimelineStringIsSafe(event.clue) ||
          visibleTo.length > chatroomMaxCollectionItems ||
          visibleTo.any((value) => !locationChatTimelineStringIsSafe(value))) {
        continue;
      }
      final visibility = event.visibility.trim().toLowerCase();
      if (visibility != 'public' && visibility != 'char_only') continue;
      if (visibility == 'char_only' && visibleTo.isEmpty) continue;
      final visibilityLabel = visibility == 'public'
          ? 'public'
          : _visibleRoleNames(visibleTo, context);
      paragraphs.add(
        ChatStoryEventParagraphVm(
          timestamp: normalizeGenesisUgcTextForDisplay(event.timestamp),
          text: normalizeGenesisUgcTextForDisplay(event.text),
          clue: normalizeGenesisUgcTextForDisplay(event.clue),
          visibilityLabel: normalizeGenesisUgcTextForDisplay(visibilityLabel),
        ),
      );
    }
    if (paragraphs.isEmpty) return null;
    final locationId = events.first.locationId.trim();
    return ChatStoryEventsPayloadVm(
      locationId: locationId,
      locationName: context.locationName(locationId),
      paragraphs: List<ChatStoryEventParagraphVm>.unmodifiable(paragraphs),
    );
  }

  String _visibleRoleNames(
    List<String> roleIds,
    LocationChatMessageParseContext context,
  ) {
    final names = <String>[];
    final seen = <String>{};
    for (final roleId in roleIds) {
      final name = context.roleName(roleId).trim();
      if (name.isEmpty || !seen.add(name)) continue;
      names.add(name);
    }
    return names.join(', ');
  }

  ChatCharactersMovedPayloadVm? _charactersMovedViewModel(
    List<ChatroomV2CharacterMovement> movements,
    LocationChatMessageParseContext context,
  ) {
    if (movements.isEmpty || movements.length > chatroomMaxCollectionItems) {
      return null;
    }
    final viewModels = <ChatCharacterMovementVm>[];
    for (final movement in movements) {
      if (!locationChatTimelineStringIsSafe(movement.characterId) ||
          !locationChatTimelineStringIsSafe(movement.oldLocationId) ||
          !locationChatTimelineStringIsSafe(movement.toLocationId)) {
        continue;
      }
      final characterId = movement.characterId.trim();
      final toLocationId = movement.toLocationId.trim();
      if (characterId.isEmpty || toLocationId.isEmpty) continue;
      viewModels.add(
        ChatCharacterMovementVm(
          characterId: characterId,
          characterName: context.characterName(characterId),
          toLocationId: toLocationId,
          toLocationName: context.locationName(toLocationId),
        ),
      );
    }
    if (viewModels.isEmpty) return null;
    return ChatCharactersMovedPayloadVm(
      movements: List<ChatCharacterMovementVm>.unmodifiable(viewModels),
    );
  }
}
