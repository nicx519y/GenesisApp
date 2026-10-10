import '../../../components/chat/shared/chat_tick_presenter.dart';
import '../../../components/chat/shared/chat_ui.dart';
import '../../../network/chatroom/chatroom_models.dart';
import '../../../network/chatroom/chatroom_timeline_payload.dart';
import '../../../network/chatroom/world_chatroom_service.dart';
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
        currentTime: payload.currentTime,
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
    return presentChatTickChapter(
      payload,
      locationName: context.locationName,
      locationExists: context.locationExists,
      isUserId: context.isUserId,
      roleName: context.roleName,
      roleAvatarUrl: context.roleAvatarUrl,
      roleIsAi: context.roleIsAi,
      restrictToLocationId: context.currentLocationId.trim(),
      requireLegacyVisibility: true,
      charactersMoved: _charactersMovedViewModel(
        payload.charactersMoved,
        context,
      ),
    );
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
