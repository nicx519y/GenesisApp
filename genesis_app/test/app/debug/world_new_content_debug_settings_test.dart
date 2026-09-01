import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/debug/world_new_content_debug_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    worldNewContentDebugSettings.resetForTesting();
  });

  tearDown(worldNewContentDebugSettings.resetForTesting);

  test('defaults to using the server is_new value', () async {
    expect(await worldNewContentDebugSettings.load(), isFalse);
    expect(worldNewContentDebugSettings.forceNewBadges, isFalse);
    expect(shouldMarkWorldContentAsNew(false), isFalse);
    expect(shouldMarkWorldContentAsNew(true), isTrue);
  });

  test('publishes and persists the force-new-badges setting', () async {
    var notifications = 0;
    void handleChanged() => notifications += 1;
    worldNewContentDebugSettings.listenable.addListener(handleChanged);

    final save = worldNewContentDebugSettings.setForceNewBadges(true);

    expect(worldNewContentDebugSettings.forceNewBadges, isTrue);
    expect(shouldMarkWorldContentAsNew(false), isTrue);
    expect(notifications, 1);
    await save;

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getBool(WorldNewContentDebugSettingsController.storageKey),
      isTrue,
    );

    worldNewContentDebugSettings.listenable.removeListener(handleChanged);
    worldNewContentDebugSettings.resetForTesting();
    expect(await worldNewContentDebugSettings.load(), isTrue);

    await worldNewContentDebugSettings.setForceNewBadges(false);
    expect(worldNewContentDebugSettings.forceNewBadges, isFalse);
    expect(shouldMarkWorldContentAsNew(false), isFalse);
    expect(shouldMarkWorldContentAsNew(true), isTrue);
    expect(
      preferences.getBool(WorldNewContentDebugSettingsController.storageKey),
      isFalse,
    );
  });
}
