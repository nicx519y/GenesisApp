import 'package:firebase_analytics/firebase_analytics.dart';
import '../privacy/privacy_consent_controller.dart';

Future<void> applyFirebaseConsent({FirebaseAnalytics? analytics}) async {
  final choices = privacyConsent.choices;
  if (choices == null) return;
  // Omitted values retain the SDK's previous/default state; this is not a
  // revocation API. Keep the original booleans in local/server storage.
  if (!choices.adStorage &&
      !choices.adUserData &&
      !choices.adPersonalization &&
      !choices.analyticsStorage) {
    return;
  }
  final client = analytics ?? FirebaseAnalytics.instance;
  await client.setConsent(
    adStorageConsentGranted: choices.adStorage ? true : null,
    adUserDataConsentGranted: choices.adUserData ? true : null,
    adPersonalizationSignalsConsentGranted: choices.adPersonalization
        ? true
        : null,
    analyticsStorageConsentGranted: choices.analyticsStorage ? true : null,
  );
  if (choices.adPersonalization) {
    await client.setConsent(adPersonalizationSignalsConsentGranted: true);
  }
}
