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
                expect(language, 'zh-TW');
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
      expect(find.byIcon(Icons.hourglass_empty_rounded), findsNothing);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('English'),
            matching: find.byType(Row),
          ),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
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
      expect(find.byIcon(Icons.hourglass_empty_rounded), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets('language switches in place and preserves page state', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await appLanguageController.load();
    final save = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      ListenableBuilder(
        listenable: appLanguageController,
        builder: (_, _) => MaterialApp(
          locale: appLanguageController.locale,
          supportedLocales: AppLanguageController.supportedLocales,
          localeListResolutionCallback: AppLanguageController.resolve,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: LanguagePage(
            saveLanguage: (_) {
              calls++;
              return calls == 1 ? save.future : Future<void>.value();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final state = tester.state(find.byType(LanguagePage));
    expect(find.text('Language'), findsOneWidget);
    await tester.tap(find.text('繁體中文'));
    await tester.pump();
    expect(find.byIcon(Icons.hourglass_empty_rounded), findsNothing);
    expect(find.text('Language'), findsOneWidget);
    save.complete();
    await tester.pump();
    expect(appLanguageController.settingLanguage, 'zh-TW');
    await tester.pump();
    final checkScale = find.byKey(const ValueKey('language-check-scale'));
    final startScale = tester
        .widget<Transform>(checkScale)
        .transform
        .entry(0, 0);
    expect(startScale, lessThan(1));
    var previousScale = startScale;
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump(const Duration(milliseconds: 75));
      final scale = tester.widget<Transform>(checkScale).transform.entry(0, 0);
      expect(scale, greaterThanOrEqualTo(previousScale));
      expect(scale, lessThanOrEqualTo(1));
      previousScale = scale;
    }
    expect(previousScale, closeTo(1, 0.001));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.widget<Transform>(checkScale).transform.entry(0, 0),
      closeTo(1, 0.001),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.hourglass_empty_rounded), findsNothing);
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
