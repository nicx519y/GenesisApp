import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/app/review/rating_prompt_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RatingPromptStore store;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = RatingPromptStore();
  });
  Future<void> send(String id, {int threshold = 2, String owner = 'a'}) =>
      store.recordMessage(
        owner: Future.value(owner),
        threshold: threshold,
        messageId: id,
      );

  test('zero and negative config do not count', () async {
    await send('1', threshold: 0);
    await send('2', threshold: -1);
    expect(
      (await SharedPreferences.getInstance()).containsKey(
        RatingPromptStore.key('a'),
      ),
      false,
    );
  });
  test('reaching threshold, deduplicated, once per owner', () async {
    await send('1');
    await send('1');
    expect(await store.takePending('a', 2), false);
    await send('2');
    expect(await store.takePending('a', 0), false);
    expect(await store.takePending('b', 2), false);
    expect(await store.takePending('a', 2), true);
    await send('4');
    expect(await store.takePending('a', 2), false);
  });
  test('threshold 20 becomes pending on message 20', () async {
    for (var index = 1; index < 20; index++) {
      await send('$index', threshold: 20);
    }
    expect(await store.takePending('a', 20), false);
    await send('20', threshold: 20);
    expect(await store.takePending('a', 20), true);
  });

  test(
    'pending state survives store recreation and later config changes',
    () async {
      await send('1', threshold: 1);
      await send('2', threshold: 1);
      store = RatingPromptStore();
      expect(await store.takePending('a', 20), true);
      expect(await RatingPromptStore().takePending('a', 1), false);
    },
  );
  test(
    'previously stored exact-threshold count is eligible without another message',
    () async {
      SharedPreferences.setMockInitialValues({
        RatingPromptStore.key('a'):
            '{"count":20,"messages":[],"pending":false}',
      });
      expect(await store.takePending('a', 20), true);
      expect(await store.takePending('a', 20), false);
    },
  );

  test('concurrent receipts and exit check preserve ordering', () async {
    final owner = Completer<String>();
    final first = store.recordMessage(
      owner: owner.future,
      threshold: 1,
      messageId: '1',
    );
    final second = send('2', threshold: 1);
    final exit = store.takePending('a', 1);
    owner.complete('a');
    await Future.wait([first, second]);
    expect(await exit, true);
  });
  test(
    'reset clears only current owner and requires reaching threshold again',
    () async {
      await send('1');
      await send('2');
      expect(await store.takePending('a', 2), true);
      await send('b1', owner: 'b', threshold: 1);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('rating_store_attempt_v1:a', true);
      await prefs.setBool('rating_reward_claimed_v1:a', true);
      await prefs.setBool('rating_reward_claimed_v1:b', true);
      await store.reset('a');
      expect(prefs.containsKey(RatingPromptStore.key('a')), false);
      await store.restorePending('a');
      expect(prefs.containsKey(RatingPromptStore.key('a')), false);
      expect(await store.takePending('a', 2), false);
      expect(prefs.getBool('rating_store_attempt_v1:a'), true);
      expect(prefs.containsKey('rating_reward_claimed_v1:a'), false);
      expect(prefs.getBool('rating_reward_claimed_v1:b'), true);
      expect(await store.takePending('b', 1), true);
      await send('new1');
      expect(await store.takePending('a', 2), false);
      await send('new2');
      expect(await store.takePending('a', 2), true);
    },
  );

  test('interrupted presentation restores eligibility', () async {
    await send('1', threshold: 1);
    await send('2', threshold: 1);
    expect(await store.takePending('a', 1), true);
    await store.restorePending('a');
    expect(await store.takePending('a', 1), true);
  });
}
