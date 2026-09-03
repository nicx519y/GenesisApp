import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/recent_chat/recent_world_chat_store.dart';

void main() {
  test('keeps only the latest in-memory recent chat record', () async {
    final store = RecentWorldChatStore();

    await store.markRecentChat(
      uid: 'user_a',
      worldId: 'world_1',
      locationId: 'loc_1_2_1',
      locationPathIds: const ['loc_1', 'loc_1_2', 'loc_1_2_1'],
    );
    await store.markRecentChat(
      uid: 'user_b',
      worldId: 'world_2',
      locationId: 'loc_2',
    );

    final record = store.listenable.value;
    expect(record?.uid, 'user_b');
    expect(record?.worldId, 'world_2');
    expect(record?.locationId, 'loc_2');
    expect(record?.locationPathIds, const <String>['loc_2']);
  });
}
