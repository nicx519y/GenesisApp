import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appLanguageController = AppLanguageController();

class AppLanguageController extends ChangeNotifier {
  static const preferenceKey = 'app_language';
  static const supportedLocales = [Locale('en'), Locale('zh', 'TW')];
  Locale? _locale;
  Locale? get locale => _locale;

  static Locale resolve(List<Locale>? preferred, Iterable<Locale> supported) {
    for (final locale in preferred ?? <Locale>[]) {
      if (locale.languageCode == 'en') return const Locale('en');
      if (locale.languageCode == 'zh' &&
          (locale.scriptCode == 'Hant' ||
              locale.countryCode == 'TW' ||
              locale.countryCode == 'HK' ||
              locale.countryCode == 'MO')) {
        return const Locale('zh', 'TW');
      }
    }
    return const Locale('en');
  }

  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getString(preferenceKey);
      _locale = saved == 'zh_TW'
          ? const Locale('zh', 'TW')
          : saved == 'en'
          ? const Locale('en')
          : null;
      notifyListeners();
    } catch (error) {
      debugPrint('[Language] Could not load preference: $error');
    }
  }

  Future<void> select(Locale locale) async {
    if (!supportedLocales.contains(locale)) throw ArgumentError.value(locale);
    if (_locale == locale) return;
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      preferenceKey,
      locale.languageCode == 'en' ? 'en' : 'zh_TW',
    );
    if (!saved) throw StateError('Could not save language');
    _locale = locale;
    notifyListeners();
  }
}
