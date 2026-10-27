import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local choices only. SDK application and startup presentation are separate.
class PrivacyChoices {
  static const denied = PrivacyChoices(
    adStorage: false,
    adUserData: false,
    adPersonalization: false,
    analyticsStorage: false,
  );
  const PrivacyChoices({
    required this.adStorage,
    required this.adUserData,
    required this.adPersonalization,
    required this.analyticsStorage,
  });

  final bool adStorage;
  final bool adUserData;
  final bool adPersonalization;
  final bool analyticsStorage;

  Map<String, bool> toJson() => {
    'ad_storage': adStorage,
    'ad_user_data': adUserData,
    'ad_personalization': adPersonalization,
    'analytics_storage': analyticsStorage,
  };
}

class PrivacyChoicesStore {
  static const storageKey = 'privacy_choices_v1';
  static const policyVersion = 1;

  static Future<PrivacyChoices?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic> ||
          data['version'] != policyVersion ||
          data['saved_at'] is! String ||
          DateTime.tryParse(data['saved_at'] as String) == null ||
          data['ad_storage'] is! bool ||
          data['ad_user_data'] is! bool ||
          data['ad_personalization'] is! bool ||
          data['analytics_storage'] is! bool) {
        return null;
      }
      return PrivacyChoices(
        adStorage: data['ad_storage'] as bool,
        adUserData: data['ad_user_data'] as bool,
        adPersonalization: data['ad_personalization'] as bool,
        analyticsStorage: data['analytics_storage'] as bool,
      );
    } on FormatException {
      return null;
    }
  }

  static Future<void> save(PrivacyChoices choices) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      storageKey,
      jsonEncode({
        'version': policyVersion,
        'saved_at': DateTime.now().toUtc().toIso8601String(),
        'ad_storage': choices.adStorage,
        'ad_user_data': choices.adUserData,
        'ad_personalization': choices.adPersonalization,
        'analytics_storage': choices.analyticsStorage,
      }),
    );
    if (!saved) throw StateError('Privacy choices could not be saved');
  }
}
