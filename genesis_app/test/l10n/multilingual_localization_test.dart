import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/l10n/app_language_controller.dart';
import 'package:genesis_flutter_android/l10n/app_localizations.dart';

void main() {
  test(
    'every offered locale loads its own catalog and renders plural parameters',
    () async {
      for (final locale in AppLanguageController.supportedLocales) {
        final l10n = await AppLocalizations.delegate.load(locale);
        expect(l10n.localeName, locale.toString());
        expect(l10n.settingsLanguage, isNotEmpty);
        for (final count in [0, 1, 2, 100]) {
          expect(l10n.newMessages(count: count), contains('$count'));
          expect(l10n.createDays(count: count), contains('$count'));
          final messages = l10n.statMessages(count: count, amount: '$count');
          expect(messages, contains('$count'));
          expect(messages, isNot(contains('{')));
        }
        expect(
          l10n.worldActionFailed(actionLabel: 'ACTION'),
          contains('ACTION'),
        );
        expect(l10n.worldoLaunched(worldName: 'WORLD'), contains('WORLD'));
      }
    },
  );

  test('regional locales map to their completed catalogs', () async {
    for (final locale in const [
      Locale('fr', 'CA'),
      Locale('pt', 'PT'),
      Locale('es', 'MX'),
    ]) {
      final resolved = AppLanguageController.resolve([
        locale,
      ], AppLanguageController.supportedLocales);
      final l10n = await AppLocalizations.delegate.load(resolved);
      expect(l10n.localeName, locale.languageCode);
    }
  });
}
