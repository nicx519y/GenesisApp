import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/debug/location_chat_bubble_layout_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    locationChatBubbleLayoutSettings.resetForTesting();
  });

  tearDown(locationChatBubbleLayoutSettings.resetForTesting);

  test(
    'reply reserve defaults to three quarters for old saved settings',
    () async {
      SharedPreferences.setMockInitialValues({
        LocationChatBubbleLayoutSettingsController
                .crowdedEffectiveWidthThresholdStorageKey:
            375.0,
      });
      final settings = await locationChatBubbleLayoutSettings.load();
      expect(settings.replyViewportReserveFraction, 0.75);
      expect(settings.crowdedEffectiveWidthThreshold, 375);
    },
  );

  test('reply reserve previews, persists and reloads independently', () async {
    locationChatBubbleLayoutSettings.previewReplyViewportReserveFraction(0.5);
    expect(
      locationChatBubbleLayoutSettings.value.replyViewportReserveFraction,
      0.5,
    );
    await locationChatBubbleLayoutSettings.save();
    locationChatBubbleLayoutSettings.resetForTesting();
    final settings = await locationChatBubbleLayoutSettings.load();
    expect(settings.replyViewportReserveFraction, 0.5);
    expect(settings.crowdedEffectiveWidthThreshold, 410);
  });

  test(
    'reply reserve clamps persisted values and rejects non-finite previews',
    () async {
      SharedPreferences.setMockInitialValues({
        LocationChatBubbleLayoutSettingsController
                .replyViewportReserveFractionStorageKey:
            2.0,
      });
      expect(
        (await locationChatBubbleLayoutSettings.load())
            .replyViewportReserveFraction,
        0.9,
      );
      locationChatBubbleLayoutSettings.previewReplyViewportReserveFraction(-1);
      expect(
        locationChatBubbleLayoutSettings.value.replyViewportReserveFraction,
        0.25,
      );
      locationChatBubbleLayoutSettings.previewReplyViewportReserveFraction(
        double.nan,
      );
      expect(
        locationChatBubbleLayoutSettings.value.replyViewportReserveFraction,
        0.75,
      );
    },
  );

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
