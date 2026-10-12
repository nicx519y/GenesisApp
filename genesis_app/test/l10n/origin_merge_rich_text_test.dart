import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui_library.dart';
import 'package:genesis_flutter_android/l10n/app_localizations.dart';
import 'package:genesis_flutter_android/ui/components/genesis_localized_rich_text.dart';

void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('Origin and movement cards preserve styled values in $locale', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(locale);
      const marker = GenesisLocalizedRichText.placeholder;
      final templates = [
        for (final count in [1, 2])
          l10n.originCharactersAtLocation(
            count: count,
            names: marker('names'),
            locationName: marker('locationName'),
          ),
        l10n.originOpeningJump(locationName: marker('locationName')),
        l10n.characterMovementSentence(
          characterName: marker('characterName'),
          direction: marker('direction'),
          locationName: '\n${marker('locationName')}',
        ),
      ];
      for (final template in templates) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 280,
                child: ChatLocationJumpCard(
                  localizedTemplate: template,
                  names: 'Ada',
                  action: l10n.cameToDirection,
                  locationName: 'Library',
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        final text = tester.widget<Text>(find.byType(Text).last);
        final rendered = text.textSpan!.toPlainText();
        expect(rendered, contains('Library'));
        expect(rendered, isNot(contains('{')));
        if (template.contains('{names}') ||
            template.contains('{characterName}')) {
          expect(rendered, contains('Ada'));
        }
      }
    });
  }
}
