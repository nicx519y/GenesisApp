import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/debug/location_chat_bubble_layout_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    locationChatBubbleLayoutSettings.resetForTesting();
  });

  tearDown(locationChatBubbleLayoutSettings.resetForTesting);

  test('stream settings default on and persist independently', () async {
    final initial = await locationChatBubbleLayoutSettings.load();
    expect(initial.animateStreamingHeight, isTrue);
    expect(initial.streamingTextReveal, isTrue);
    expect(initial.streamingHeightDurationMs, 180);
    expect(initial.streamingTextDurationMs, 120);
    expect(initial.effectiveStreamingTextDurationMs, 6);
    expect(initial.replyWaitingPositioningEnabled, isTrue);
    locationChatBubbleLayoutSettings.previewStreamingAnimations(
      heightEnabled: false,
      textEnabled: false,
      heightDurationMs: 400,
      textDurationMs: 760,
    );
    await locationChatBubbleLayoutSettings.save();
    locationChatBubbleLayoutSettings.resetForTesting();
    final stored = await locationChatBubbleLayoutSettings.load();
    expect(stored.animateStreamingHeight, isFalse);
    expect(stored.streamingTextReveal, isFalse);
    expect(stored.streamingHeightDurationMs, 400);
    expect(stored.streamingTextDurationMs, 760);
    expect(stored.effectiveStreamingTextDurationMs, 38);
    expect(stored.replyViewportReserveFraction, .85);
  });

  test(
    'animation duration loading normalizes invalid values and old data',
    () async {
      SharedPreferences.setMockInitialValues({
        LocationChatBubbleLayoutSettingsController
                .streamingHeightDurationStorageKey:
            -1,
        LocationChatBubbleLayoutSettingsController
                .streamingTextDurationStorageKey:
            99999,
        LocationChatBubbleLayoutSettingsController
                .streamingTextEnabledStorageKey:
            'bad',
      });
      final stored = await locationChatBubbleLayoutSettings.load();
      expect(stored.streamingHeightDurationMs, 40);
      expect(stored.streamingTextDurationMs, 1000);
      expect(stored.streamingTextReveal, isTrue);
      locationChatBubbleLayoutSettings.previewStreamingAnimations(
        heightDurationMs: 191,
        textDurationMs: double.nan,
      );
      expect(
        locationChatBubbleLayoutSettings.value.streamingHeightDurationMs,
        200,
      );
      expect(
        locationChatBubbleLayoutSettings.value.streamingTextDurationMs,
        120,
      );
    },
  );

  test('pending load cannot overwrite a streaming animation preview', () async {
    final loading = locationChatBubbleLayoutSettings.load();
    locationChatBubbleLayoutSettings.previewReplyWaitingPositioningEnabled(
      false,
    );
    locationChatBubbleLayoutSettings.previewStreamingAnimations(
      textEnabled: false,
      heightDurationMs: 640,
    );
    await loading;
    expect(
      locationChatBubbleLayoutSettings.value.replyWaitingPositioningEnabled,
      isFalse,
    );
    expect(locationChatBubbleLayoutSettings.value.streamingTextReveal, isFalse);
    expect(
      locationChatBubbleLayoutSettings.value.streamingHeightDurationMs,
      640,
    );
  });

  test(
    'reply reserve defaults to three quarters for old saved settings',
    () async {
      SharedPreferences.setMockInitialValues({
        LocationChatBubbleLayoutSettingsController
                .crowdedEffectiveWidthThresholdStorageKey:
            375.0,
        LocationChatBubbleLayoutSettingsController
                .replyWaitingPositioningEnabledStorageKey:
            'bad',
      });
      final settings = await locationChatBubbleLayoutSettings.load();
      expect(settings.replyWaitingPositioningEnabled, isTrue);
      expect(settings.replyViewportReserveFraction, 0.85);
      expect(settings.crowdedEffectiveWidthThreshold, 375);
    },
  );

  test('reply positioning toggle and reserve persist independently', () async {
    locationChatBubbleLayoutSettings.previewReplyWaitingPositioningEnabled(
      false,
    );
    locationChatBubbleLayoutSettings.previewReplyViewportReserveFraction(0.5);
    expect(
      locationChatBubbleLayoutSettings.value.replyViewportReserveFraction,
      0.5,
    );
    await locationChatBubbleLayoutSettings.save();
    locationChatBubbleLayoutSettings.resetForTesting();
    final settings = await locationChatBubbleLayoutSettings.load();
    expect(settings.replyWaitingPositioningEnabled, isFalse);
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
        0.85,
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
