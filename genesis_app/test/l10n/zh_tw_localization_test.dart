import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/l10n/app_localizations.dart';
import 'package:genesis_flutter_android/l10n/genesis_l10n.dart';

void main() {
  final taiwan = lookupAppLocalizations(const Locale('zh', 'TW'));

  test(
    'Taiwan locale uses translated navigation and preserves brand names',
    () {
      expect(taiwan.navHome, '首頁');
      expect(taiwan.navWorldo, 'Worldo');
      expect(taiwan.tickNowAction, '立即推進');
      expect(
        taiwan.homeMyWorldsEmptyTitle(worldo: '#Worldo'),
        '開啟一個 #Worldo，打造\n屬於你的世界',
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
    expect(lookupAppLocalizations(locale).navHome, '首頁');
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
          builder: (context) => Text(AppLocalizations.of(context).navHome),
        ),
      ),
    );
    expect(find.text('首頁'), findsOneWidget);
  });
}
