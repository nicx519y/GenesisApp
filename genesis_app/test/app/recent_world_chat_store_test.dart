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

  test('stores world activity tags per uid with display priority', () async {
    final store = WorldActivityTagStore();

    await store.markLastLaunch(uid: 'user_a', worldId: 'world_launch');
    await store.markLastTick(uid: 'user_a', worldId: 'world_tick');
    await store.markLastMessage(uid: 'user_a', worldId: 'world_tick');

    await store.markLastLaunch(uid: 'user_b', worldId: 'world_b');

    final userAState = await store.loadForUid('user_a');
    expect(userAState?.lastLaunchWorldId, 'world_launch');
    expect(userAState?.lastTickWorldId, 'world_tick');
    expect(userAState?.lastMessageWorldId, 'world_tick');
    expect(userAState?.labelForWorldId('world_tick'), 'Last Message');
    expect(userAState?.labelForWorldId('world_launch'), 'Last Launch');
    expect(userAState?.labelForWorldId('world_other'), '');

    final userBState = await store.loadForUid('user_b');
    expect(userBState?.lastLaunchWorldId, 'world_b');
    expect(userBState?.lastTickWorldId, '');
    expect(userBState?.lastMessageWorldId, '');
  });

  test('marking recent chat also updates last message world tag', () async {
    final recentStore = RecentWorldChatStore();

    await recentStore.markRecentChat(
      uid: 'user_a',
      worldId: 'world_1',
      locationId: 'loc_1',
    );

    final activityState = await worldActivityTagStore.loadForUid('user_a');
    expect(activityState?.lastMessageWorldId, 'world_1');
    expect(activityState?.labelForWorldId('world_1'), 'Last Message');
  });
}
