import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/debug/location_chat_bubble_layout_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    locationChatBubbleLayoutSettings.resetForTesting();
  });

  tearDown(locationChatBubbleLayoutSettings.resetForTesting);

  test('defaults to a 410 logical-pixel crowded width threshold', () {
    expect(
      LocationChatBubbleLayoutSettings.defaultCrowdedEffectiveWidthThreshold,
      410,
    );
    expect(
      locationChatBubbleLayoutSettings.value.crowdedEffectiveWidthThreshold,
      410,
    );
  });

  test('loads and clamps a persisted crowded width threshold', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      LocationChatBubbleLayoutSettingsController
              .crowdedEffectiveWidthThresholdStorageKey:
          800.0,
    });

    final settings = await locationChatBubbleLayoutSettings.load();

    expect(
      settings.crowdedEffectiveWidthThreshold,
      LocationChatBubbleLayoutSettings.maxCrowdedEffectiveWidthThreshold,
    );
  });

  test('previews immediately and persists the final threshold', () async {
    locationChatBubbleLayoutSettings.previewCrowdedEffectiveWidthThreshold(375);

    expect(
      locationChatBubbleLayoutSettings.value.crowdedEffectiveWidthThreshold,
      375,
    );

    await locationChatBubbleLayoutSettings.save();
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getDouble(
        LocationChatBubbleLayoutSettingsController
            .crowdedEffectiveWidthThresholdStorageKey,
      ),
      375,
    );
  });
}
