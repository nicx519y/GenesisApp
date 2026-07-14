import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';
import 'package:genesis_flutter_android/platform/session/method_channel_user_session_store.dart';
import 'package:genesis_flutter_android/platform/session/user_info_cache.dart';

void main() {
  test('current user cache keeps fields alongside user', () async {
    final sessionStore = MemoryUserSessionStore();
    await sessionStore.saveUserInfo({'uid': 'old_uid', 'name': 'Old name'});

    final cached = await cacheCurrentUserInfoResponse(
      sessionStore: sessionStore,
      response: {
        'user': {'uid': 'u_1', 'name': 'New name'},
        'uuid': 'bf5bc735-39c0-4b4d-a622-a44eeb17dada',
        'selected_model_code': 'luxury_selection_v4',
      },
    );

    expect(cached, containsPair('uid', 'u_1'));
    expect(cached, containsPair('name', 'New name'));
    expect(
      cached,
      containsPair('uuid', 'bf5bc735-39c0-4b4d-a622-a44eeb17dada'),
    );
    expect(cached, containsPair('selected_model_code', 'luxury_selection_v4'));
    expect(
      await sessionStore.readUserInfo(),
      containsPair('selected_model_code', 'luxury_selection_v4'),
    );
  });

  test('saving user info notifies active cache listeners', () async {
    final sessionStore = MemoryUserSessionStore();
    var notifications = 0;
    sessionStore.userInfoRevision.addListener(() => notifications += 1);

    await sessionStore.saveUserInfo({
      'uid': 'u_1',
      'selected_model_code': 'top_pick_v3',
    });

    expect(notifications, 1);
  });

  test('native session store exposes the latest cached user info', () async {
    final sessionStore = NativeUserSessionStore(
      fallback: MemoryUserSessionStore(),
    );
    var notifications = 0;
    sessionStore.userInfoRevision.addListener(() => notifications += 1);

    await sessionStore.saveUserInfo({
      'uid': 'u_1',
      'selected_model_code': 'luxury_selection_v4',
    });

    expect(notifications, 1);
    expect(
      await sessionStore.readUserInfo(),
      containsPair('selected_model_code', 'luxury_selection_v4'),
    );
  });
}
