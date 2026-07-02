import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/chatroom/world_chatroom_service.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_page.dart';

void main() {
  const localAvatar = 'https://example.test/local-avatar.webp';
  const fallbackAvatar = 'https://example.test/fallback-avatar.webp';
  const entityAvatar = 'https://example.test/entity-avatar.webp';

  test('location chat panel hides the inactive more button by default', () {
    const panel = LocationChatPanel(worldId: 'world-1', locationId: 'loc-1');

    expect(panel.showMoreButton, isFalse);
  });

  test('location chat background falls back to bundled default when empty', () {
    expect(
      resolveLocationChatBackgroundUrlForTesting(imageUrl: ''),
      'assets/images/map_default/location_default.webp',
    );
  });

  test('location chat background maps predata default CDN image to asset', () {
    expect(
      resolveLocationChatBackgroundUrlForTesting(
        imageUrl: 'https://cdn-001.worldo.ai/predata/location_default.webp',
      ),
      'assets/images/map_default/location_default.webp',
    );
  });

  test(
    'self message avatar falls back to local avatar before existing avatar',
    () {
      expect(
        resolveLocationChatMessageAvatarForTesting(
          isMine: true,
          localSelfAvatar: localAvatar,
          fallback: fallbackAvatar,
        ),
        localAvatar,
      );
    },
  );

  test('self message avatar keeps existing avatar when source is empty', () {
    expect(
      resolveLocationChatMessageAvatarForTesting(
        isMine: true,
        fallback: fallbackAvatar,
      ),
      fallbackAvatar,
    );
  });

  test('source avatar wins over local and existing avatar fallbacks', () {
    expect(
      resolveLocationChatMessageAvatarForTesting(
        entityUserAvatar: entityAvatar,
        isMine: true,
        localSelfAvatar: localAvatar,
        fallback: fallbackAvatar,
      ),
      entityAvatar,
    );
  });

  test('name list uses AI role names instead of real user names', () {
    const state = WorldChatroomState(
      entitiesByLocation: {
        'loc-1': [
          WorldChatroomEntity(
            id: 'ai-1',
            name: 'Alice',
            avatarUrl: '',
            type: WorldChatroomEntityType.character,
            locationId: 'loc-1',
            isAi: true,
          ),
          WorldChatroomEntity(
            id: 'user-1',
            name: 'Real User Role',
            avatarUrl: '',
            type: WorldChatroomEntityType.player,
            locationId: 'loc-1',
          ),
          WorldChatroomEntity(
            id: 'ai-2',
            name: 'Guide',
            avatarUrl: '',
            type: WorldChatroomEntityType.character,
            locationId: 'loc-1',
            isAi: true,
          ),
        ],
        'loc-alias': [
          WorldChatroomEntity(
            id: 'ai-1',
            name: 'Alice',
            avatarUrl: '',
            type: WorldChatroomEntityType.character,
            locationId: 'loc-alias',
            isAi: true,
          ),
        ],
      },
    );

    expect(
      resolveLocationChatAiRoleNamesForTesting(state, ['loc-1', 'loc-alias']),
      ['Alice', 'Guide'],
    );
  });

  test(
    'visible location chat messages keep latest continuous location id suffix',
    () {
      final visible = visibleLocationChatMessagesForTesting([
        _message(messageId: 10, locationMessageId: 1, content: 'old 1'),
        _message(messageId: 20, locationMessageId: 2, content: 'old 2'),
        _message(
          messageId: 30,
          locationMessageId: 0,
          senderType: 'tick',
          content: 'tick before gap',
        ),
        _message(messageId: 40, locationMessageId: 4, content: 'new 4'),
        _message(
          messageId: 45,
          locationMessageId: 0,
          senderType: 'tick',
          content: 'tick in visible range',
        ),
        _message(messageId: 50, locationMessageId: 5, content: 'new 5'),
      ]);

      expect(visible.map((message) => message.messageId), [40, 45, 50]);
      expect(
        locationChatMessageGapFillCursorForTesting([
          _message(messageId: 10, locationMessageId: 1, content: 'old 1'),
          _message(messageId: 40, locationMessageId: 4, content: 'new 4'),
          _message(messageId: 50, locationMessageId: 5, content: 'new 5'),
        ]),
        4,
      );
    },
  );

  test(
    'visible location chat messages render all continuous location messages',
    () {
      final source = [
        _message(messageId: 10, locationMessageId: 1, content: 'one'),
        _message(
          messageId: 15,
          locationMessageId: 0,
          senderType: 'tick',
          content: 'tick',
        ),
        _message(messageId: 20, locationMessageId: 2, content: 'two'),
        _message(messageId: 30, locationMessageId: 3, content: 'three'),
      ];

      expect(
        visibleLocationChatMessagesForTesting(
          source,
        ).map((message) => message.messageId),
        [10, 15, 20, 30],
      );
      expect(locationChatMessageGapFillCursorForTesting(source), 0);
    },
  );
}

WorldChatroomMessage _message({
  required int messageId,
  required int locationMessageId,
  required String content,
  String senderType = 'user',
}) {
  return WorldChatroomMessage(
    messageId: messageId,
    locationMessageId: locationMessageId,
    conversationRoundId: '$messageId',
    roundOrder: 0,
    tickNo: senderType == 'tick' ? messageId : 0,
    locationId: 'loc-1',
    senderType: senderType,
    senderId: senderType == 'tick' ? 'tick' : 'u_peer',
    senderName: senderType == 'tick' ? 'Time' : 'Peer',
    content: content,
    createdAt: null,
  );
}
