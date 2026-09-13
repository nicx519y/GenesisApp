import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_reply_render_snapshot.dart';

ChatMessageVm _message({ChatTimelinePayloadVm? payload}) => ChatMessageVm(
  localId: 'local',
  clientMsgId: 'client',
  globalMessageId: 11,
  messageId: 12,
  locationMessageId: 13,
  roundId: 'round',
  tickNo: 14,
  subTickNo: 15,
  senderId: 'sender',
  senderName: 'Name',
  avatarUrl: 'avatar',
  imageUrl: 'image',
  timelinePayload: payload,
  isPlayerControlledRole: true,
  text: 'Original reply',
  currentTime: 'time',
  isMe: true,
  status: 'failed',
  senderType: 'character',
  createdAt: DateTime.utc(2026, 9, 13),
)..error = 'original error';

void main() {
  test('reply snapshot preserves every field when its source is mutated', () {
    final source = _message();
    final expected = _message();
    final sourceList = [source];
    final frozenList = freezeLocationChatReplyMessages(sourceList);
    final frozen = frozenList.single;
    expect(identical(frozen, source), isFalse);
    expect(locationChatReplyMessagesEqual(frozen, source), isTrue);
    source
      ..clientMsgId = 'new-client'
      ..globalMessageId = 21
      ..messageId = null
      ..locationMessageId = 23
      ..roundId = 'new-round'
      ..tickNo = 24
      ..subTickNo = 25
      ..senderName = 'New name'
      ..avatarUrl = 'new-avatar'
      ..imageUrl = 'new-image'
      ..timelinePayload = const ChatTickProgressPayloadVm(title: 'New')
      ..isPlayerControlledRole = false
      ..text = 'Updated reply'
      ..currentTime = 'new-time'
      ..isMe = false
      ..status = 'sent'
      ..error = null;
    sourceList.clear();
    expect(frozenList, hasLength(1));
    expect(locationChatReplyMessagesEqual(frozen, expected), isTrue);
    expect(locationChatReplyMessagesEqual(frozen, source), isFalse);
    expect(() => frozenList.clear(), throwsUnsupportedError);
  });

  test('each mutable presentation field invalidates the frozen value', () {
    final mutations = <String, void Function(ChatMessageVm)>{
      'clientMsgId': (value) => value.clientMsgId = 'changed',
      'globalMessageId': (value) => value.globalMessageId++,
      'messageId': (value) => value.messageId = null,
      'locationMessageId': (value) => value.locationMessageId++,
      'roundId': (value) => value.roundId = 'changed',
      'tickNo': (value) => value.tickNo++,
      'subTickNo': (value) => value.subTickNo++,
      'senderName': (value) => value.senderName = 'changed',
      'avatarUrl': (value) => value.avatarUrl = 'changed',
      'imageUrl': (value) => value.imageUrl = 'changed',
      'timelinePayload': (value) => value.timelinePayload =
          const ChatTickProgressPayloadVm(title: 'changed'),
      'isPlayerControlledRole': (value) => value.isPlayerControlledRole = false,
      'text': (value) => value.text = 'changed',
      'currentTime': (value) => value.currentTime = 'changed',
      'isMe': (value) => value.isMe = false,
      'status': (value) => value.status = 'changed',
      'error': (value) => value.error = null,
    };
    for (final mutation in mutations.entries) {
      final source = _message();
      final frozen = freezeLocationChatReplyMessage(source);
      expect(locationChatReplyMessagesEqual(source, frozen), isTrue);
      mutation.value(source);
      expect(
        locationChatReplyMessagesEqual(source, frozen),
        isFalse,
        reason: mutation.key,
      );
    }
  });

  test('snapshot isolates nested story roles and character movements', () {
    final roles = <ChatStoryEventVisibleRoleVm>[
      const ChatStoryEventVisibleRoleVm(
        roleId: 'role',
        name: 'Role',
        isAi: true,
        avatarUrl: 'role-avatar',
      ),
    ];
    final paragraphs = <ChatStoryEventParagraphVm>[
      ChatStoryEventParagraphVm(
        timestamp: 'time',
        text: 'Story',
        clue: 'Clue',
        visibilityLabel: 'Visible',
        visibleRoles: roles,
        locationId: 'location',
        locationName: 'Location',
      ),
    ];
    final movements = <ChatCharacterMovementVm>[
      const ChatCharacterMovementVm(
        characterId: 'character',
        characterName: 'Character',
        toLocationId: 'destination',
        toLocationName: 'Destination',
        isDestinationCurrentLocation: true,
      ),
    ];
    final source = _message(
      payload: ChatTickPayloadVm(
        globalText: 'Global',
        storyEvents: ChatStoryEventsPayloadVm(
          locationId: 'location',
          locationName: 'Location',
          paragraphs: paragraphs,
        ),
        charactersMoved: ChatCharactersMovedPayloadVm(movements: movements),
        fallbackContent: 'Fallback',
      ),
    );
    final frozen = freezeLocationChatReplyMessage(source);
    final payload = frozen.timelinePayload! as ChatTickPayloadVm;
    expect(locationChatReplyMessagesEqual(source, frozen), isTrue);
    roles.clear();
    expect(locationChatReplyMessagesEqual(source, frozen), isFalse);
    paragraphs.clear();
    movements.clear();
    expect(payload.globalText, 'Global');
    expect(payload.fallbackContent, 'Fallback');
    expect(payload.storyEvents!.paragraphs, hasLength(1));
    expect(payload.storyEvents!.paragraphs.single.visibleRoles, hasLength(1));
    expect(payload.charactersMoved!.movements, hasLength(1));
    expect(
      () => payload.storyEvents!.paragraphs.clear(),
      throwsUnsupportedError,
    );
    expect(
      () => payload.storyEvents!.paragraphs.single.visibleRoles.clear(),
      throwsUnsupportedError,
    );
    expect(
      () => payload.charactersMoved!.movements.clear(),
      throwsUnsupportedError,
    );
  });

  test('snapshot also isolates standalone timeline collections', () {
    final avatars = <ChatTickProgressAvatarVm>[
      const ChatTickProgressAvatarVm(name: 'Name', url: 'avatar'),
    ];
    final progress =
        freezeLocationChatReplyMessage(
              _message(
                payload: ChatTickProgressPayloadVm(
                  title: 'Wait',
                  avatars: avatars,
                ),
              ),
            ).timelinePayload!
            as ChatTickProgressPayloadVm;
    avatars.clear();
    expect(progress.avatars.single.name, 'Name');
    expect(() => progress.avatars.clear(), throwsUnsupportedError);

    final paragraphs = <ChatStoryEventParagraphVm>[];
    final movements = <ChatCharacterMovementVm>[];
    final payloads = <ChatTimelinePayloadVm>[
      ChatStoryEventsPayloadVm(
        locationId: 'location',
        locationName: 'Location',
        paragraphs: paragraphs,
      ),
      ChatCharactersMovedPayloadVm(movements: movements),
      const ChatUserEnterLocationPayloadVm(
        characterId: 'character',
        toLocationId: 'location',
        text: 'Entered',
      ),
    ];
    for (final payload in payloads) {
      final source = _message(payload: payload);
      final frozen = freezeLocationChatReplyMessage(source);
      expect(locationChatReplyMessagesEqual(source, frozen), isTrue);
      switch (frozen.timelinePayload) {
        case ChatStoryEventsPayloadVm(:final paragraphs):
          expect(() => paragraphs.clear(), throwsUnsupportedError);
        case ChatCharactersMovedPayloadVm(:final movements):
          expect(() => movements.clear(), throwsUnsupportedError);
        default:
          break;
      }
    }
  });
}
