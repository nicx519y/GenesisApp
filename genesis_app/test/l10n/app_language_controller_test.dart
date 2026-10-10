import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/l10n/app_language_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'first launch follows system and unsupported language falls back',
    () async {
      SharedPreferences.setMockInitialValues({});
      final controller = AppLanguageController();
      await controller.load();
      expect(controller.locale, isNull);
      expect(
        AppLanguageController.resolve([
          const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        ], []),
        const Locale('zh', 'TW'),
      );
      expect(
        AppLanguageController.resolve([const Locale('en', 'US')], []),
        const Locale('en'),
      );
      expect(
        AppLanguageController.resolve([const Locale('de')], []),
        const Locale('en'),
      );
    },
  );
  test('manual language persists across controller recreation', () async {
    SharedPreferences.setMockInitialValues({});
    final first = AppLanguageController();
    await first.select(const Locale('zh', 'TW'));
    final second = AppLanguageController();
    await second.load();
    expect(second.locale, const Locale('zh', 'TW'));
    await second.select(const Locale('en'));
    await first.load();
    expect(first.locale, const Locale('en'));
  });
}
