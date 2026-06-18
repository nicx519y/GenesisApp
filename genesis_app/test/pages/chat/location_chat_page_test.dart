import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/chatroom/world_chatroom_service.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_page.dart';

void main() {
  test(
    'self message avatar falls back to local avatar before existing avatar',
    () {
      expect(
        resolveLocationChatMessageAvatarForTesting(
          isMine: true,
          localSelfAvatar: 'assets/images/mock_avatars/avatar_jules.png',
          fallback: 'assets/images/mock_avatars/avatar_iris.png',
        ),
        'assets/images/mock_avatars/avatar_jules.png',
      );
    },
  );

  test('self message avatar keeps existing avatar when source is empty', () {
    expect(
      resolveLocationChatMessageAvatarForTesting(
        isMine: true,
        fallback: 'assets/images/mock_avatars/avatar_iris.png',
      ),
      'assets/images/mock_avatars/avatar_iris.png',
    );
  });

  test('source avatar wins over local and existing avatar fallbacks', () {
    expect(
      resolveLocationChatMessageAvatarForTesting(
        entityUserAvatar: 'assets/images/mock_avatars/avatar_crow.png',
        isMine: true,
        localSelfAvatar: 'assets/images/mock_avatars/avatar_jules.png',
        fallback: 'assets/images/mock_avatars/avatar_iris.png',
      ),
      'assets/images/mock_avatars/avatar_crow.png',
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
}
