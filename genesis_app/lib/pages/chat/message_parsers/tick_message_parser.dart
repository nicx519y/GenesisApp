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
    final currentLocationId = context.currentLocationId.trim();
    for (final event in events) {
      final eventLocationId = event.locationId.trim();
      if (currentLocationId.isNotEmpty &&
          eventLocationId != currentLocationId) {
        continue;
      }
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
      final visibleRoles = visibility == 'public'
          ? const <ChatStoryEventVisibleRoleVm>[]
          : _visibleRoles(visibleTo, context);
      final visibilityLabel = visibility == 'public'
          ? 'public'
          : visibleRoles.map((role) => role.name).join(', ');
      final locationId = eventLocationId;
      paragraphs.add(
        ChatStoryEventParagraphVm(
          timestamp: normalizeGenesisUgcTextForDisplay(event.timestamp),
          text: normalizeGenesisUgcTextForDisplay(event.text),
          clue: normalizeGenesisUgcTextForDisplay(event.clue),
          visibilityLabel: normalizeGenesisUgcTextForDisplay(visibilityLabel),
          visibleRoles: List<ChatStoryEventVisibleRoleVm>.unmodifiable(
            visibleRoles,
          ),
          locationId: locationId,
          locationName: context.locationName(locationId),
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

  List<ChatStoryEventVisibleRoleVm> _visibleRoles(
    List<String> roleIds,
    LocationChatMessageParseContext context,
  ) {
    final roles = <ChatStoryEventVisibleRoleVm>[];
    final seenNames = <String>{};
    for (final roleId in roleIds) {
      final name = context.roleName(roleId).trim();
      if (name.isEmpty || !seenNames.add(name)) continue;
      roles.add(
        ChatStoryEventVisibleRoleVm(
          roleId: roleId.trim(),
          name: name,
          isAi: context.roleIsAi(roleId) ?? false,
        ),
      );
    }
    return roles;
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
          isDestinationCurrentLocation:
              context.currentLocationId.trim().isNotEmpty &&
              toLocationId == context.currentLocationId.trim(),
        ),
      );
    }
    if (viewModels.isEmpty) return null;
    return ChatCharactersMovedPayloadVm(
      movements: List<ChatCharacterMovementVm>.unmodifiable(viewModels),
    );
  }
}
