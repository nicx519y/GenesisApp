import 'package:firebase_analytics/firebase_analytics.dart';
import '../privacy/privacy_consent_controller.dart';

Future<void> applyFirebaseConsent() async {
  final choices = privacyConsent.choices;
  if (choices == null) return;
  final analytics = FirebaseAnalytics.instance;
  await analytics.setConsent(
    adStorageConsentGranted: choices.adStorage,
    adUserDataConsentGranted: choices.adUserData,
    adPersonalizationSignalsConsentGranted: choices.adPersonalization,
    analyticsStorageConsentGranted: choices.analyticsStorage,
  );
  await analytics.setConsent(
    adPersonalizationSignalsConsentGranted: choices.adPersonalization,
  );
}
