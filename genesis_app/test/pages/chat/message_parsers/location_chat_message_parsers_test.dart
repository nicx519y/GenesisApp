import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_models.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_timeline_payload.dart';
import 'package:genesis_flutter_android/network/chatroom/world_chatroom_service.dart';
import 'package:genesis_flutter_android/pages/chat/message_parsers/location_chat_message_parsers.dart';

void main() {
  final context = LocationChatMessageParseContext(
    currentLocationId: 'loc-2',
    isMine: (message) => message.senderId == 'me',
    senderName: (message) => 'resolved:${message.senderName}',
    avatarUrl: (message) => 'avatar:${message.senderId}',
    isPlayerControlledRole: (message) => message.userId == 'player',
    characterName: (id) => id == 'char-1' ? 'Alice' : id,
    locationName: (id) => switch (id) {
      'loc-2' => 'Cafe',
      'loc-3' => 'Tower',
      _ => id,
    },
    roleName: (id) => switch (id) {
      'char-1' => 'Alice',
      'char-2' => 'Bob',
      _ => '',
    },
    roleIsAi: (id) => switch (id) {
      'char-1' => true,
      'char-2' => false,
      _ => null,
    },
    roleAvatarUrl: (id) => 'avatar:$id',
  );

  group('TextMessageParser', () {
    test('parses common metadata, identity, and streaming text', () {
      final parsed = const TextMessageParser().parse(
        _message(
          senderType: 'ai',
          senderId: 'me',
          userId: 'player',
          content: r'Line\nTwo',
          streaming: true,
          isLlmStreamMessage: true,
        ),
        context,
      );

      expect(parsed.localId, 'location-loc-1-10');
      expect(parsed.senderType, 'character');
      expect(parsed.text, 'Line\nTwo');
      expect(parsed.status, 'streaming');
      expect(parsed.isMe, isTrue);
      expect(parsed.isPlayerControlledRole, isTrue);
      expect(parsed.senderName, 'resolved:Sender');
      expect(parsed.avatarUrl, 'avatar:me');
    });
  });

  group('ImageMessageParser', () {
    test('maps display text to the image URL', () {
      final parsed = const ImageMessageParser().parse(
        _message(
          senderType: 'narrator',
          senderId: 'nar_pic',
          content: ' https://cdn.example.com/pic.webp ',
        ),
        context,
      );

      expect(parsed.senderType, 'image');
      expect(parsed.imageUrl, 'https://cdn.example.com/pic.webp');
      expect(parsed.text, ' https://cdn.example.com/pic.webp ');
    });
  });

  group('NarratorMessageParser', () {
    test('produces narrator bubble data', () {
      final parsed = const NarratorMessageParser().parse(
        _message(
          senderType: 'narrator',
          senderId: 'nar',
          content: 'Narration',
          currentTime: 'Day 2',
        ),
        context,
      );

      expect(parsed.senderType, 'narrator');
      expect(parsed.text, 'Narration');
      expect(parsed.currentTime, 'Day 2');
    });
  });

  group('TickMessageParser', () {
    test('preserves tick metadata while hiding sender current time', () {
      final parsed = const TickMessageParser().parse(
        _message(
          senderType: 'tick',
          senderId: 'tick',
          content: 'Time advances',
          tickNo: 4,
          subTickNo: 2,
          currentTime: 'Day 2',
        ),
        context,
      );

      expect(parsed.senderType, 'tick');
      expect(parsed.tickNo, 4);
      expect(parsed.subTickNo, 2);
      expect(parsed.currentTime, isEmpty);
    });

    test('projects every V2 tick section into one composite view model', () {
      final parsed = const TickMessageParser().parse(
        _message(
          senderType: 'tick',
          businessType: 'tick',
          tickNo: 0,
          subTickNo: 0,
          currentTime: '',
          v2TickPayload: const ChatroomV2TickPayload(
            currentTime: 'Day 1, 13:50',
            tickNo: 1,
            subTickNo: 2,
            globalText: 'The key pulses.',
            storyEvents: [
              ChatroomV2StoryEvent(
                locationId: 'loc-2',
                timestamp: 'Day 1, 13:30',
                visibility: 'char_only',
                visibleTo: ['char-1', 'char-2'],
                text: 'Frost spreads.',
                clue: 'It spells Elara.',
              ),
              ChatroomV2StoryEvent(
                locationId: 'loc-3',
                timestamp: 'Day 1, 13:35',
                visibility: 'public',
                visibleTo: null,
                text: 'The tower bell rings.',
                clue: '',
              ),
            ],
            charactersMoved: [
              ChatroomV2CharacterMovement(
                characterId: 'char-1',
                oldLocationId: 'loc-1',
                toLocationId: 'loc-2',
              ),
            ],
            fallbackContent: '',
          ),
        ),
        context,
      );

      final payload = parsed.timelinePayload as ChatTickPayloadVm;
      expect(parsed.tickNo, 1);
      expect(parsed.subTickNo, 2);
      expect(parsed.currentTime, 'Day 1, 13:50');
      expect(payload.globalText, 'The key pulses.');
      expect(payload.storyEvents?.locationName, 'Cafe');
      expect(
        payload.storyEvents?.paragraphs.first.visibilityLabel,
        'Alice, Bob',
      );
      expect(payload.storyEvents?.paragraphs.first.visibleRoles, const [
        ChatStoryEventVisibleRoleVm(
          roleId: 'char-1',
          name: 'Alice',
          isAi: true,
          avatarUrl: 'avatar:char-1',
        ),
        ChatStoryEventVisibleRoleVm(
          roleId: 'char-2',
          name: 'Bob',
          isAi: false,
          avatarUrl: 'avatar:char-2',
        ),
      ]);
      expect(payload.storyEvents?.paragraphs, hasLength(1));
      expect(payload.storyEvents?.paragraphs.single.locationName, 'Cafe');
      expect(
        payload.storyEvents?.paragraphs.any(
          (event) => event.locationName == 'Tower',
        ),
        isFalse,
      );
      expect(payload.charactersMoved?.movements.single.characterName, 'Alice');
      expect(payload.charactersMoved?.movements.single.toLocationName, 'Cafe');
      expect(
        payload.charactersMoved?.movements.single.isDestinationCurrentLocation,
        isTrue,
      );
      expect(payload.fallbackContent, isEmpty);
    });

    test('preserves V2 fallback content without inventing empty sections', () {
      final parsed = const TickMessageParser().parse(
        _message(
          senderType: 'tick',
          businessType: 'tick',
          v2TickPayload: const ChatroomV2TickPayload(
            currentTime: '',
            tickNo: 0,
            subTickNo: 0,
            globalText: '',
            storyEvents: [],
            charactersMoved: [],
            fallbackContent: 'Original content',
          ),
        ),
        context,
      );

      final payload = parsed.timelinePayload as ChatTickPayloadVm;
      expect(payload.hasStructuredSections, isFalse);
      expect(payload.fallbackContent, 'Original content');
      expect(parsed.text, 'Original content');
    });
  });

  group('UserEnterLocationMessageParser', () {
    test('parses its structured timeline payload', () {
      final parsed = const UserEnterLocationMessageParser().parse(
        _message(
          senderType: chatroomUserEnterLocationSenderType,
          timelinePayload: const ChatroomUserEnterLocationPayload(
            charId: ' char-1 ',
            toLocationId: ' loc-2 ',
            text: 'Alice enters.',
          ),
        ),
        context,
      );

      expect(
        parsed?.timelinePayload,
        const ChatUserEnterLocationPayloadVm(
          characterId: 'char-1',
          toLocationId: 'loc-2',
          text: 'Alice enters.',
        ),
      );
      expect(parsed?.text, 'Alice enters.');
    });

    test('rejects a missing payload', () {
      final parsed = const UserEnterLocationMessageParser().parse(
        _message(senderType: chatroomUserEnterLocationSenderType),
        context,
      );

      expect(parsed, isNull);
    });
  });

  group('StoryEventsMessageParser', () {
    test('resolves location and visibility labels', () {
      final parsed = const StoryEventsMessageParser().parse(
        _message(
          senderType: chatroomStoryEventsSenderType,
          timelinePayload: const ChatroomStoryEventsPayload(
            locationId: 'loc-2',
            locationName: '',
            paragraphs: [
              ChatroomStoryEventParagraph(
                timestamp: 'Day 2',
                visibility: 'char_only',
                visibleTo: ['char-1', 'missing', 'char-2', 'char-1'],
                text: 'An event.',
                clue: 'A clue.',
              ),
            ],
          ),
        ),
        context,
      );

      final payload = parsed?.timelinePayload as ChatStoryEventsPayloadVm?;
      expect(payload?.locationName, 'Cafe');
      expect(payload?.paragraphs.single.visibilityLabel, 'Alice, Bob');
      expect(payload?.paragraphs.single.locationName, 'Cafe');
      expect(parsed?.text, contains('An event.'));
      expect(parsed?.text, contains('A clue.'));
    });

    test('rejects an empty paragraph collection', () {
      final parsed = const StoryEventsMessageParser().parse(
        _message(
          senderType: chatroomStoryEventsSenderType,
          timelinePayload: const ChatroomStoryEventsPayload(
            locationId: 'loc-2',
            locationName: '',
            paragraphs: [],
          ),
        ),
        context,
      );

      expect(parsed, isNull);
    });

    test('rejects oversized paragraph content', () {
      final parsed = const StoryEventsMessageParser().parse(
        _message(
          senderType: chatroomStoryEventsSenderType,
          timelinePayload: ChatroomStoryEventsPayload(
            locationId: 'loc-2',
            locationName: '',
            paragraphs: [
              ChatroomStoryEventParagraph(
                timestamp: '',
                visibility: 'public',
                visibleTo: const [],
                text: 'x' * (chatroomMaxStringCodeUnits + 1),
                clue: '',
              ),
            ],
          ),
        ),
        context,
      );

      expect(parsed, isNull);
    });
  });

  group('CharactersMovedMessageParser', () {
    test('resolves character and destination names', () {
      final parsed = const CharactersMovedMessageParser().parse(
        _message(
          senderType: chatroomCharactersMovedSenderType,
          timelinePayload: const ChatroomCharactersMovedPayload(
            movements: [
              ChatroomCharacterMovement(
                charId: 'char-1',
                toLocationId: 'loc-2',
              ),
            ],
          ),
        ),
        context,
      );

      final payload = parsed?.timelinePayload as ChatCharactersMovedPayloadVm?;
      expect(payload?.movements.single.characterName, 'Alice');
      expect(payload?.movements.single.toLocationName, 'Cafe');
      expect(payload?.movements.single.isDestinationCurrentLocation, isTrue);
      expect(parsed?.text, 'Alice → Cafe');
    });

    test('rejects an empty movement collection', () {
      final parsed = const CharactersMovedMessageParser().parse(
        _message(
          senderType: chatroomCharactersMovedSenderType,
          timelinePayload: const ChatroomCharactersMovedPayload(movements: []),
        ),
        context,
      );

      expect(parsed, isNull);
    });

    test('rejects oversized movement identifiers', () {
      final parsed = const CharactersMovedMessageParser().parse(
        _message(
          senderType: chatroomCharactersMovedSenderType,
          timelinePayload: ChatroomCharactersMovedPayload(
            movements: [
              ChatroomCharacterMovement(
                charId: 'x' * (chatroomMaxStringCodeUnits + 1),
                toLocationId: 'loc-2',
              ),
            ],
          ),
        ),
        context,
      );

      expect(parsed, isNull);
    });
  });
}

WorldChatroomMessage _message({
  String senderType = 'user',
  String businessType = '',
  String senderId = 'sender',
  String userId = '',
  String content = 'Message',
  int tickNo = 0,
  int subTickNo = 0,
  String currentTime = '',
  bool streaming = false,
  bool isLlmStreamMessage = false,
  ChatroomTimelinePayload? timelinePayload,
  ChatroomV2TickPayload? v2TickPayload,
}) {
  return WorldChatroomMessage(
    globalMessageId: 100,
    messageId: 20,
    locationMessageId: 10,
    conversationRoundId: '3',
    roundOrder: 1,
    tickNo: tickNo,
    subTickNo: subTickNo,
    locationId: 'loc-1',
    senderType: senderType,
    businessType: businessType,
    userId: userId,
    senderId: senderId,
    senderName: 'Sender',
    clientMsgId: 'client-1',
    content: content,
    currentTime: currentTime,
    createdAt: DateTime.utc(2026, 8, 10),
    streaming: streaming,
    isLlmStreamMessage: isLlmStreamMessage,
    timelinePayload: timelinePayload,
    v2TickPayload: v2TickPayload,
  );
}
