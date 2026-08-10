import '../../../components/chat/shared/chat_ui.dart';
import '../../../network/chatroom/chatroom_timeline_payload.dart';
import '../../../network/chatroom/world_chatroom_service.dart';
import '../../../utils/genesis_ugc_text.dart';
import '../../../utils/llm_stream_escape_decoder.dart';
import 'location_chat_message_parse_context.dart';
import 'location_chat_parsed_message.dart';

LocationChatParsedMessage buildLocationChatParsedMessage({
  required WorldChatroomMessage message,
  required LocationChatMessageParseContext context,
  required String senderType,
  required String text,
  String imageUrl = '',
  ChatTimelinePayloadVm? timelinePayload,
}) {
  return LocationChatParsedMessage(
    source: message,
    localId: locationChatMessageLocalId(message),
    clientMsgId: message.clientMsgId,
    globalMessageId: message.globalMessageId,
    messageId: message.messageId,
    locationMessageId: message.locationMessageId,
    roundId: message.conversationRoundId,
    tickNo: message.tickNo,
    subTickNo: message.subTickNo,
    senderId: message.senderId,
    senderName: context.senderName(message),
    avatarUrl: context.avatarUrl(message),
    imageUrl: imageUrl,
    timelinePayload: timelinePayload,
    isPlayerControlledRole: context.isPlayerControlledRole(message),
    text: text,
    currentTime: locationChatMessageCurrentTime(message),
    isMe: context.isMine(message),
    status: message.streaming ? 'streaming' : 'sent',
    senderType: senderType,
    createdAt: message.createdAt ?? DateTime.now(),
  );
}

String locationChatMessageLocalId(WorldChatroomMessage message) {
  if (!isChatroomMessageIdOrderedSupplemental(
        message.senderType,
        locationMessageId: message.locationMessageId,
      ) &&
      message.locationMessageId > 0) {
    return 'location-${message.locationId}-${message.locationMessageId}';
  }
  if (message.messageId > 0) {
    return 'message-${message.locationId}-${message.messageId}';
  }
  return 'stream-${message.locationId}-${message.conversationRoundId}-${message.senderId}';
}

String locationChatMessageDisplayText(WorldChatroomMessage message) {
  if (message.isLlmStreamMessage) {
    return decodeLlmStreamTextForDisplay(
      message.content,
      isStreaming: message.streaming,
    );
  }
  final senderType = message.senderType.trim().toLowerCase();
  if (senderType.isEmpty || senderType == 'user') {
    return decodeGenesisUgcTextForDisplay(message.content);
  }
  return normalizeGenesisUgcTextForDisplay(message.content);
}

String locationChatResolvedSenderType(WorldChatroomMessage message) {
  final senderType = message.senderType.trim().toLowerCase();
  if (senderType == 'narrator') {
    return locationChatSenderIdIsNarrator(message.senderId)
        ? 'narrator'
        : 'character';
  }
  if (senderType == 'tick') return 'tick';
  if (senderType == 'ai') return 'character';
  return senderType.isEmpty ? 'user' : senderType;
}

String locationChatMessageCurrentTime(WorldChatroomMessage message) {
  if (message.senderType.trim().toLowerCase() ==
      chatroomStoryEventsSenderType) {
    return message.currentTime.trim();
  }
  if (isChatroomTimelinePayloadSenderType(message.senderType)) return '';
  final senderType = locationChatResolvedSenderType(message);
  if (senderType == 'user' || senderType == 'tick' || senderType == 'system') {
    return '';
  }
  return message.currentTime.trim();
}

bool locationChatSenderIdIsNarrator(String senderId) {
  final normalized = senderId.trim().toLowerCase();
  return normalized == 'nar' || normalized == 'nar_pic';
}

bool locationChatTimelineStringIsSafe(String value) {
  return value.length <= chatroomMaxStringCodeUnits;
}

String locationChatTimelineCopyText(ChatTimelinePayloadVm payload) {
  return switch (payload) {
    ChatUserEnterLocationPayloadVm event => event.text,
    ChatStoryEventsPayloadVm event => [
      if (event.locationName.trim().isNotEmpty) event.locationName,
      for (final paragraph in event.paragraphs) ...[
        [
          if (paragraph.timestamp.trim().isNotEmpty) paragraph.timestamp,
          if (paragraph.visibilityLabel.trim().isNotEmpty)
            paragraph.visibilityLabel,
        ].join(' · '),
        paragraph.text,
        if (paragraph.clue.trim().isNotEmpty) paragraph.clue,
      ],
    ].join('\n'),
    ChatCharactersMovedPayloadVm event =>
      event.movements
          .map(
            (movement) =>
                '${movement.characterName} → ${movement.toLocationName}',
          )
          .join('\n'),
  };
}
