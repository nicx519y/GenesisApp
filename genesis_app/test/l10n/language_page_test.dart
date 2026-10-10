import 'dart:async';
import 'package:genesis_flutter_android/network/api_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/l10n/app_language_controller.dart';
import 'package:genesis_flutter_android/l10n/app_localizations.dart';
import 'package:genesis_flutter_android/pages/me/language_page.dart';

void main() {
  testWidgets(
    'pending selection stays unchanged and business failure shows server copy',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await appLanguageController.load();
      appLanguageController.applyConfigLanguage(
        'en',
        requestRevision: appLanguageController.revision,
      );
      final save = Completer<void>();
      var requests = 0;
      await tester.pumpWidget(
        ListenableBuilder(
          listenable: appLanguageController,
          builder: (_, _) => MaterialApp(
            locale: appLanguageController.locale,
            supportedLocales: AppLanguageController.supportedLocales,
            localeListResolutionCallback: AppLanguageController.resolve,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: LanguagePage(
              saveLanguage: (language) {
                requests++;
                expect(language, 'zh_TW');
                return save.future;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('繁體中文'));
      await tester.pump();
      expect(find.text('Language'), findsOneWidget);
      expect(appLanguageController.settingLanguage, 'en');
      await tester.tap(find.text('繁體中文'));
      expect(requests, 1);
      save.completeError(
        ApiException(
          message: 'Server language save failed',
          kind: ApiExceptionKind.business,
        ),
      );
      await tester.pumpAndSettle();
      expect(appLanguageController.settingLanguage, 'en');
      expect(find.text('Server language save failed'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    },
  );

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
          home: LanguagePage(saveLanguage: (_) async {}),
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
