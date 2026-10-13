import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/l10n/app_localizations.dart';
import 'package:genesis_flutter_android/pages/world/world_bottom_sheet.dart';
import 'package:genesis_flutter_android/pages/world/world_models.dart';

void main() {
  testWidgets('world tags update language without replacing selected kind', (
    tester,
  ) async {
    final locale = ValueNotifier(const Locale('zh', 'TW'));
    addTearDown(locale.dispose);
    var selected = WorldBottomSheetKind.recap;
    await tester.pumpWidget(
      ValueListenableBuilder<Locale>(
        valueListenable: locale,
        builder: (_, value, __) => MaterialApp(
          locale: value,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: WorldBottomTags(
              relationStatus: 'owner',
              onTap: (kind) => selected = kind,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final item in worldBottomTagItemsFor(
      lookupAppLocalizations(const Locale('zh', 'TW')),
    )) {
      expect(find.text(item.label), findsOneWidget);
    }
    locale.value = const Locale('en');
    await tester.pumpAndSettle();
    for (final item in worldBottomTagItemsFor(
      lookupAppLocalizations(const Locale('en')),
    )) {
      expect(find.text(item.label), findsOneWidget);
    }
    expect(selected, WorldBottomSheetKind.recap);
  });
}
