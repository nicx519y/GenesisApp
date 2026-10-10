import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/l10n/app_language_controller.dart';
import 'package:genesis_flutter_android/l10n/app_localizations.dart';
import 'package:genesis_flutter_android/pages/me/language_page.dart';

void main() {
  testWidgets('language switches in place and preserves page state', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await appLanguageController.load();
    await tester.pumpWidget(
      ListenableBuilder(
        listenable: appLanguageController,
        builder: (_, _) => MaterialApp(
          locale: appLanguageController.locale,
          supportedLocales: AppLanguageController.supportedLocales,
          localeListResolutionCallback: AppLanguageController.resolve,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const LanguagePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final state = tester.state(find.byType(LanguagePage));
    expect(find.text('Language'), findsOneWidget);
    await tester.tap(find.text('繁體中文'));
    await tester.pumpAndSettle();
    expect(find.text('語言'), findsOneWidget);
    expect(tester.state(find.byType(LanguagePage)), same(state));
    expect(find.byIcon(Icons.check), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getString(
        AppLanguageController.preferenceKey,
      ),
      'en',
    );
  });
}
