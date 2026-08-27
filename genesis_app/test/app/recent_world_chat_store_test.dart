import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/recent_chat/recent_world_chat_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('stores recent chat location per uid', () async {
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

    final userARecord = await store.loadForUid('user_a');
    expect(userARecord?.worldId, 'world_1');
    expect(userARecord?.locationId, 'loc_1_2_1');
    expect(userARecord?.locationPathIds, ['loc_1', 'loc_1_2', 'loc_1_2_1']);

    final userBRecord = await store.loadForUid('user_b');
    expect(userBRecord?.worldId, 'world_2');
    expect(userBRecord?.locationId, 'loc_2');
    expect(store.listenable.value?.uid, 'user_b');
  });
}
