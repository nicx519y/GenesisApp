import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/l10n/app_localizations.dart';
import 'package:genesis_flutter_android/l10n/genesis_l10n.dart';

void main() {
  final taiwan = lookupAppLocalizations(const Locale('zh', 'TW'));

  test(
    'Taiwan locale preserves English navigation and localizes other copy',
    () {
      expect(taiwan.navHome, 'Home');
      expect(taiwan.navWorldo, 'Worldo');
      expect(taiwan.navInbox, 'Inbox');
      expect(taiwan.navMe, 'Me');
      expect(taiwan.navCreate, 'Create');
      expect(taiwan.tickNowAction, '立即 Tick');
      expect(
        taiwan.homeMyWorldsEmptyTitle(worldo: '#Worldo'),
        '啟動一個 #Worldo，打造\n屬於你的世界',
      );
    },
  );

  test('non-Taiwan Chinese keeps the English fallback', () {
    final baseChinese = lookupAppLocalizations(const Locale('zh'));
    final english = lookupAppLocalizations(const Locale('en'));
    expect(baseChinese.navHome, english.navHome);
    expect(baseChinese.tickNowAction, english.tickNowAction);
  });

  test('script-tagged Taiwan locale resolves to Taiwan copy', () {
    final locale = resolveGenesisSupportedLocale(
      const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hant',
        countryCode: 'TW',
      ),
      AppLocalizations.supportedLocales,
    );
    expect(locale, const Locale('zh', 'TW'));
    expect(lookupAppLocalizations(locale).navHome, 'Home');
  });

  testWidgets('MaterialApp renders Taiwan copy for zh-Hant-TW', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
          countryCode: 'TW',
        ),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Text(AppLocalizations.of(context).settingsLanguage),
        ),
      ),
    );
    expect(find.text('語言'), findsOneWidget);
  });
}
