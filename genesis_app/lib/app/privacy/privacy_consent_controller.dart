import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../config/app_global_config.dart';
import 'privacy_choices_store.dart';
import '../startup/startup_prompt_sequence.dart';

/// System locale is a product-selected approximation, not geolocation.
class PrivacyRegion {
  const PrivacyRegion(this.countryCode);
  final String? countryCode;
  static const eeaCountries = {
    'AT',
    'BE',
    'BG',
    'HR',
    'CY',
    'CZ',
    'DK',
    'EE',
    'FI',
    'FR',
    'DE',
    'GR',
    'HU',
    'IE',
    'IT',
    'LV',
    'LT',
    'LU',
    'MT',
    'NL',
    'PL',
    'PT',
    'RO',
    'SK',
    'SI',
    'ES',
    'SE',
    'IS',
    'LI',
    'NO',
  };
  String? get normalized => countryCode?.trim().toUpperCase();
  bool get unknown => normalized == null || normalized!.length != 2;
  String? get eea =>
      unknown ? null : (eeaCountries.contains(normalized) ? '1' : '0');
  bool get needsPrompt =>
      unknown || eea == '1' || normalized == 'GB' || normalized == 'CH';
}

final privacyConsent = PrivacyConsentController();

/// Owns privacy presentation and explicit saved choices only.
class PrivacyConsentController extends ChangeNotifier {
  bool active = false;
  bool loaded = false;
  bool startupResolved = false;
  PrivacyChoices? choices;
  PrivacyRegion region = const PrivacyRegion(null);
  Future<void>? _loading;
  Completer<void> _startupReady = Completer<void>();

  Future<void> get startupReady =>
      active ? _startupReady.future : Future<void>.value();

  String? get registrationJson =>
      choices == null ? null : jsonEncode(choices!.toJson());
  void retrySynchronization() {
    if (active && loaded) notifyListeners();
  }

  Future<void> initialize({Locale? systemLocale}) {
    if (!active) startupPromptSequence.begin();
    active = true;
    return _loading ??= _load(
      systemLocale ?? PlatformDispatcher.instance.locale,
    );
  }

  Future<void> _load(Locale locale) async {
    region = PrivacyRegion(locale.countryCode);
    try {
      choices = await PrivacyChoicesStore.read().timeout(
        const Duration(seconds: 2),
      );
    } catch (error) {
      debugPrint('[Privacy] local choice read failed: $error');
    }
    loaded = true;
    notifyListeners();
  }

  bool configEnabled(AppGlobalConfigStore config) {
    final request = config.requestState.value;
    return !request.isLoading &&
        request.error == null &&
        request.data != null &&
        config.value.privacyConsentEnabled;
  }

  bool shouldPrompt(AppGlobalConfigStore config) =>
      loaded &&
      !startupResolved &&
      configEnabled(config) &&
      region.needsPrompt &&
      choices == null;

  bool showSettings(AppGlobalConfigStore config) =>
      loaded &&
      configEnabled(config) &&
      (region.needsPrompt || choices != null);

  void resolveStartup({AppGlobalConfigStore? config}) {
    if (startupResolved) return;
    startupResolved = true;
    if (!_startupReady.isCompleted) _startupReady.complete();
    startupPromptSequence.finishPrivacy();
    notifyListeners();
  }

  Future<void> save(PrivacyChoices value) async {
    await PrivacyChoicesStore.save(value);
    choices = value;
    loaded = true;
    notifyListeners();
  }

  @visibleForTesting
  void resetForTesting() {
    startupPromptSequence.value = StartupPromptStage.ready;
    active = loaded = startupResolved = false;
    choices = null;
    region = const PrivacyRegion(null);
    _loading = null;
    _startupReady = Completer<void>();
  }
}
