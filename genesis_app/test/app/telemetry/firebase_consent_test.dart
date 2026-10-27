import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/app/privacy/privacy_choices_store.dart';
import 'package:genesis_flutter_android/app/privacy/privacy_consent_controller.dart';
import 'package:genesis_flutter_android/app/telemetry/firebase_consent.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    privacyConsent.resetForTesting();
  });
  tearDown(privacyConsent.resetForTesting);

  for (var mask = 0; mask < 16; mask++) {
    test('only grants reach Firebase for choice mask $mask', () async {
      await privacyConsent.initialize(systemLocale: const Locale('de', 'DE'));
      final choice = PrivacyChoices(
        adStorage: mask & 1 != 0,
        adUserData: mask & 2 != 0,
        adPersonalization: mask & 4 != 0,
        analyticsStorage: mask & 8 != 0,
      );
      await privacyConsent.save(choice);
      final client = _Analytics();
      await applyFirebaseConsent(analytics: client);
      expect(
        client.calls.length,
        mask == 0
            ? 0
            : choice.adPersonalization
            ? 2
            : 1,
      );
      if (mask != 0) {
        expect(client.calls.first, {
          'ad_storage': choice.adStorage ? true : null,
          'ad_user_data': choice.adUserData ? true : null,
          'ad_personalization': choice.adPersonalization ? true : null,
          'analytics_storage': choice.analyticsStorage ? true : null,
        });
      }
      final count = client.calls.length;
      await privacyConsent.save(PrivacyChoices.denied);
      await applyFirebaseConsent(analytics: client);
      expect(client.calls.length, count);
      expect(privacyConsent.choices!.toJson(), PrivacyChoices.denied.toJson());
    });
  }
}

class _Analytics extends Fake implements FirebaseAnalytics {
  final calls = <Map<String, bool?>>[];
  @override
  Future<void> setConsent({
    bool? adStorageConsentGranted,
    bool? analyticsStorageConsentGranted,
    bool? adPersonalizationSignalsConsentGranted,
    bool? adUserDataConsentGranted,
    bool? functionalityStorageConsentGranted,
    bool? personalizationStorageConsentGranted,
    bool? securityStorageConsentGranted,
  }) async {
    calls.add({
      'ad_storage': adStorageConsentGranted,
      'ad_user_data': adUserDataConsentGranted,
      'ad_personalization': adPersonalizationSignalsConsentGranted,
      'analytics_storage': analyticsStorageConsentGranted,
    });
  }
}
