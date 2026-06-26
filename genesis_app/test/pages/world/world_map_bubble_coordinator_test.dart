import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/chatroom/world_chatroom_service.dart';
import 'package:genesis_flutter_android/pages/world/world_map_bubble_coordinator.dart';

void main() {
  WorldChatroomMessage message({
    required int id,
    required String senderId,
    required String senderName,
    String senderType = 'character',
    String locationId = 'loc-1',
    String content = 'hello',
    int roundOrder = 0,
    bool streaming = false,
  }) {
    return WorldChatroomMessage(
      messageId: id,
      conversationRoundId: '1',
      roundOrder: roundOrder,
      tickNo: 1,
      locationId: locationId,
      senderType: senderType,
      senderId: senderId,
      senderName: senderName,
      content: content,
      createdAt: DateTime.utc(2026, 1, 1, 0, 0, id),
      streaming: streaming,
    );
  }

  WorldMapBubbleCoordinator coordinator() {
    return WorldMapBubbleCoordinator(
      worldId: 'wid-1',
      isMounted: () => true,
      world: () => null,
      chatroom: () => null,
      descriptors: () => const [],
      requestUiUpdate: () {},
    );
  }

  test(
    'enqueues only non-streaming character messages with display content',
    () {
      final subject = coordinator();
      addTearDown(subject.dispose);

      final queued = subject.enqueue([
        message(id: 1, senderId: 'character-1', senderName: 'Alice'),
        message(
          id: 2,
          senderId: 'user-1',
          senderName: 'User',
          senderType: 'user',
        ),
        message(
          id: 3,
          senderId: 'character-2',
          senderName: 'Bob',
          streaming: true,
        ),
      ], priority: true);

      expect(queued, isTrue);
      expect(subject.messageBubbles, contains('loc-1'));
      expect(subject.messageBubbles['loc-1']?.senderName, 'Alice');
    },
  );

  test('cleans markdown before bubble display', () {
    final subject = coordinator();
    addTearDown(subject.dispose);

    final text = subject.displayContentForTesting('''
# Heading
> Quote
Hello **bold** [link](https://example.com)
```dart
print('hidden');
```
''');

    expect(text, 'Hello');
  });

  test(
    'interleaves messages by sender instead of grouping one speaker first',
    () {
      final subject = coordinator();
      addTearDown(subject.dispose);

      final ordered = subject.interleaveBySenderForTesting([
        message(id: 1, senderId: 'a', senderName: 'A', roundOrder: 1),
        message(id: 2, senderId: 'a', senderName: 'A', roundOrder: 2),
        message(id: 3, senderId: 'b', senderName: 'B', roundOrder: 3),
        message(id: 4, senderId: 'b', senderName: 'B', roundOrder: 4),
      ]);

      expect(ordered.map((item) => item.senderId), ['a', 'b', 'a', 'b']);
    },
  );
}
