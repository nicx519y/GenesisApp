import '../../components/chat/shared/chat_ui.dart';

/// Isolates a displayed reply from later in-place updates to its business VM.
///
/// The returned VM belongs to the presentation cache. Nested collections are
/// copied and made unmodifiable; callers must treat the VM itself as read-only.
ChatMessageVm freezeLocationChatReplyMessage(ChatMessageVm message) =>
    ChatMessageVm(
      localId: message.localId,
      clientMsgId: message.clientMsgId,
      globalMessageId: message.globalMessageId,
      messageId: message.messageId,
      locationMessageId: message.locationMessageId,
      roundId: message.roundId,
      tickNo: message.tickNo,
      subTickNo: message.subTickNo,
      senderId: message.senderId,
      senderName: message.senderName,
      avatarUrl: message.avatarUrl,
      imageUrl: message.imageUrl,
      timelinePayload: _freezeTimelinePayload(message.timelinePayload),
      isPlayerControlledRole: message.isPlayerControlledRole,
      text: message.text,
      currentTime: message.currentTime,
      isMe: message.isMe,
      status: message.status,
      senderType: message.senderType,
      createdAt: message.createdAt,
    )..error = message.error;

List<ChatMessageVm> freezeLocationChatReplyMessages(
  Iterable<ChatMessageVm> messages,
) => List<ChatMessageVm>.unmodifiable(
  messages.map(freezeLocationChatReplyMessage),
);

/// Compare against a frozen VM so in-place source updates invalidate the cache.
bool locationChatReplyMessagesEqual(ChatMessageVm a, ChatMessageVm b) =>
    a.localId == b.localId &&
    a.clientMsgId == b.clientMsgId &&
    a.globalMessageId == b.globalMessageId &&
    a.messageId == b.messageId &&
    a.locationMessageId == b.locationMessageId &&
    a.roundId == b.roundId &&
    a.tickNo == b.tickNo &&
    a.subTickNo == b.subTickNo &&
    a.senderId == b.senderId &&
    a.senderName == b.senderName &&
    a.avatarUrl == b.avatarUrl &&
    a.imageUrl == b.imageUrl &&
    a.timelinePayload == b.timelinePayload &&
    a.isPlayerControlledRole == b.isPlayerControlledRole &&
    a.text == b.text &&
    a.currentTime == b.currentTime &&
    a.isMe == b.isMe &&
    a.status == b.status &&
    a.senderType == b.senderType &&
    a.createdAt == b.createdAt &&
    a.error == b.error;

ChatTimelinePayloadVm? _freezeTimelinePayload(
  ChatTimelinePayloadVm? payload,
) => switch (payload) {
  null => null,
  ChatTickProgressPayloadVm() => ChatTickProgressPayloadVm(
    title: payload.title,
    avatars: List<ChatTickProgressAvatarVm>.unmodifiable(payload.avatars),
  ),
  // All fields in this payload, avatar, movement and visible-role values are
  // immutable. Only their owning collections need independent copies.
  ChatUserEnterLocationPayloadVm() => payload,
  ChatStoryEventsPayloadVm() => _freezeStoryEvents(payload),
  ChatCharactersMovedPayloadVm() => _freezeCharactersMoved(payload),
  ChatTickPayloadVm() => ChatTickPayloadVm(
    globalText: payload.globalText,
    storyEvents: payload.storyEvents == null
        ? null
        : _freezeStoryEvents(payload.storyEvents!),
    charactersMoved: payload.charactersMoved == null
        ? null
        : _freezeCharactersMoved(payload.charactersMoved!),
    fallbackContent: payload.fallbackContent,
  ),
};

ChatStoryEventsPayloadVm _freezeStoryEvents(ChatStoryEventsPayloadVm payload) =>
    ChatStoryEventsPayloadVm(
      locationId: payload.locationId,
      locationName: payload.locationName,
      paragraphs: List<ChatStoryEventParagraphVm>.unmodifiable(
        payload.paragraphs.map(
          (paragraph) => ChatStoryEventParagraphVm(
            timestamp: paragraph.timestamp,
            text: paragraph.text,
            clue: paragraph.clue,
            visibilityLabel: paragraph.visibilityLabel,
            visibleRoles: List<ChatStoryEventVisibleRoleVm>.unmodifiable(
              paragraph.visibleRoles,
            ),
            locationId: paragraph.locationId,
            locationName: paragraph.locationName,
          ),
        ),
      ),
    );

ChatCharactersMovedPayloadVm _freezeCharactersMoved(
  ChatCharactersMovedPayloadVm payload,
) => ChatCharactersMovedPayloadVm(
  movements: List<ChatCharacterMovementVm>.unmodifiable(payload.movements),
);
