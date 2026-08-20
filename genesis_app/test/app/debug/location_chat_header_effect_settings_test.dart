import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/debug/location_chat_header_effect_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    locationChatHeaderEffectSettings.resetForTesting();
  });

  tearDown(locationChatHeaderEffectSettings.resetForTesting);

  test('defaults keep the location scene overlay unobstructed', () async {
    final settings = await locationChatHeaderEffectSettings.load();

    expect(settings.transparencyStrength, 0);
    expect(settings.blurSigma, 0);
  });

  test('loads and clamps persisted LocationChat header effects', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      LocationChatHeaderEffectSettingsController.transparencyStorageKey: -1.0,
      LocationChatHeaderEffectSettingsController.blurSigmaStorageKey: 40.0,
    });

    final settings = await locationChatHeaderEffectSettings.load();

    expect(settings.transparencyStrength, 0);
    expect(settings.blurSigma, 20);
  });

  test('previews immediately and persists the final values', () async {
    locationChatHeaderEffectSettings.previewTransparencyStrength(0.35);
    locationChatHeaderEffectSettings.previewBlurSigma(6);

    expect(
      locationChatHeaderEffectSettings.value,
      const LocationChatHeaderEffectSettings(
        transparencyStrength: 0.35,
        blurSigma: 6,
      ),
    );

    await locationChatHeaderEffectSettings.save();
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getDouble(
        LocationChatHeaderEffectSettingsController.transparencyStorageKey,
      ),
      0.35,
    );
    expect(
      prefs.getDouble(
        LocationChatHeaderEffectSettingsController.blurSigmaStorageKey,
      ),
      6,
    );
  });
}
