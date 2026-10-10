import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appLanguageController = AppLanguageController();

class AppLanguageController extends ChangeNotifier {
  static const preferenceKey = 'app_language';
  // Protocol values are agreed with the backend; Traditional Chinese is zh-TW.
  static const languageCodes = {
    'en',
    'zh-TW',
    'es',
    'pt',
    'fr',
    'de',
    'it',
    'ja',
    'ko',
  };
  // Only languages with complete app translations are offered in the UI.
  static const supportedLocales = [
    Locale('en'),
    Locale('zh', 'TW'),
    Locale('es'),
    Locale('pt'),
    Locale('fr'),
    Locale('de'),
    Locale('it'),
    Locale('ja'),
    Locale('ko'),
  ];
  Locale? _locale;
  String? _settingLanguage;
  bool _userLanguageApplied = false;
  bool _saving = false;
  SharedPreferences? _preferences;
  int _revision = 0;
  int _dataRevision = 0;

  /// Changes only when the confirmed request language changes.
  int get dataRevision => _dataRevision;
  Locale? get locale => _locale;
  String? get settingLanguage => _settingLanguage;
  int get revision => _revision;

  static String codeForLocale(Locale locale) =>
      locale == const Locale('zh', 'TW') ? 'zh-TW' : locale.languageCode;

  static Locale resolve(List<Locale>? preferred, Iterable<Locale> supported) {
    for (final locale in preferred ?? <Locale>[]) {
      if (locale.languageCode != 'zh') {
        for (final candidate in supported) {
          if (candidate.languageCode == locale.languageCode) return candidate;
        }
      }
      if (locale.languageCode == 'zh' &&
          (locale.scriptCode == 'Hant' ||
              locale.countryCode == 'TW' ||
              locale.countryCode == 'HK' ||
              locale.countryCode == 'MO')) {
        if (supported.contains(const Locale('zh', 'TW'))) {
          return const Locale('zh', 'TW');
        }
      }
    }
    return const Locale('en');
  }

  // Restore a saved setting before runApp; server settings remain authoritative.
  Future<void> load() async {
    _locale = null;
    if (_settingLanguage != null) _dataRevision++;
    _settingLanguage = null;
    _userLanguageApplied = false;
    final requestRevision = ++_revision;
    try {
      final preferences = await SharedPreferences.getInstance();
      _preferences = preferences;
      if (requestRevision != _revision ||
          _saving ||
          _settingLanguage != null ||
          _userLanguageApplied) {
        return;
      }
      final cached = preferences.getString(preferenceKey);
      if (cached != null && languageCodes.contains(cached)) {
        _apply(cached);
        return;
      }
    } catch (error) {
      debugPrint('[Language] Could not read preference: $error');
    }
    notifyListeners();
  }

  void applyConfigLanguage(String? language, {required int requestRevision}) {
    if (_saving || _userLanguageApplied || requestRevision != _revision) return;
    _applyServerLanguage(language);
  }

  void applyUserLanguage(String? language, {required int requestRevision}) {
    if (_saving || requestRevision != _revision) return;
    if (_applyServerLanguage(language)) _userLanguageApplied = true;
  }

  bool _applyServerLanguage(String? language) {
    final code = language?.trim() ?? '';
    if (!languageCodes.contains(code)) return false;
    _apply(code);
    unawaited(_persistLanguage(code));
    return true;
  }

  Future<void> _persistLanguage(String code) async {
    try {
      final preferences = _preferences ?? await SharedPreferences.getInstance();
      // Do not let an earlier asynchronous save replace a newer setting.
      if (_settingLanguage != code) return;
      _preferences = preferences;
      await preferences.setString(preferenceKey, code);
    } catch (error) {
      debugPrint('[Language] Could not cache preference: $error');
    }
  }

  void _apply(String code) {
    // The protocol and completed UI bundles use the same nine language values.
    final requested = code == 'zh-TW' ? const Locale('zh', 'TW') : Locale(code);
    final display = resolve([requested], supportedLocales);
    if (_settingLanguage == code && _locale == display) return;
    if (_settingLanguage != code) _dataRevision++;
    _settingLanguage = code;
    _locale = display;
    notifyListeners();
  }

  Future<void> select(
    Locale locale, {
    required Future<void> Function(String language) saveLanguage,
  }) async {
    if (!supportedLocales.contains(locale)) throw ArgumentError.value(locale);
    final code = codeForLocale(locale);
    if (_saving || _settingLanguage == code) return;
    _saving = true;
    // Invalidate responses initiated before this explicit user action.
    _revision++;
    try {
      await saveLanguage(code);
      _apply(code);
      // Server confirmation is authoritative; a local cache failure must not
      // turn a successful server save into an apparent failed language change.
      await _persistLanguage(code);
    } finally {
      // Also discard profile responses started while saving was in progress.
      _revision++;
      _saving = false;
    }
  }
}
