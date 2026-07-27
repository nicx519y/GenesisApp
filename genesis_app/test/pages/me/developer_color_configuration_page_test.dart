import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/me/developer_color_configuration_page.dart';
import 'package:genesis_flutter_android/ui/genesis_ui.dart';

void main() {
  testWidgets(
    'developer color page switches and edits Light and Dark independently',
    (tester) async {
      final controller = GenesisColorController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        AnimatedBuilder(
          animation: controller,
          builder: (context, _) => GenesisColorScope(
            controller: controller,
            child: MaterialApp(
              theme: GenesisTheme.light(
                config: controller.lightConfig,
                revision: controller.revision,
              ),
              darkTheme: GenesisTheme.dark(
                config: controller.darkConfig,
                revision: controller.revision,
              ),
              themeMode: controller.mode,
              home: const DeveloperColorConfigurationPage(),
            ),
          ),
        ),
      );

      expect(find.text('Color configuration'), findsOneWidget);
      final surfaceCount = GenesisColorToken.values
          .where((token) => token.group == GenesisColorGroup.surface)
          .length;
      expect(find.text('Surface ($surfaceCount)'), findsOneWidget);
      final modeSwitch = find.byKey(
        const ValueKey<String>('developer-colors-dark-mode-switch'),
      );
      expect(tester.widget<SwitchListTile>(modeSwitch).value, isFalse);

      await tester.tap(modeSwitch);
      await tester.pumpAndSettle();
      expect(controller.mode, ThemeMode.dark);
      expect(tester.widget<SwitchListTile>(modeSwitch).value, isTrue);

      await controller.setColor(
        Brightness.dark,
        GenesisColorToken.surface,
        const Color(0xFF050505),
      );
      await tester.pumpAndSettle();
      expect(
        controller.colorFor(Brightness.dark, GenesisColorToken.surface),
        const Color(0xFF050505),
      );
      expect(
        controller.colorFor(Brightness.light, GenesisColorToken.surface),
        GenesisColorDefaults.light.color(GenesisColorToken.surface),
      );
    },
  );

  testWidgets('developer color page filters tokens and exposes reset actions', (
    tester,
  ) async {
    final controller = GenesisColorController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      GenesisColorScope(
        controller: controller,
        child: MaterialApp(
          theme: GenesisTheme.light(),
          home: const DeveloperColorConfigurationPage(),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('developer-colors-search-field')),
      'location chat',
    );
    await tester.pump();
    expect(find.text('Location chat background'), findsOneWidget);
    expect(find.text('Page surface'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('developer-colors-reset-all')),
      findsOneWidget,
    );
    final resetPaletteButton = find.byKey(
      const ValueKey<String>('developer-colors-reset-palette'),
      skipOffstage: false,
    );
    await tester.scrollUntilVisible(
      resetPaletteButton,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(resetPaletteButton, findsOneWidget);
  });

  testWidgets('color picker applies on OK and discards changes on Cancel', (
    tester,
  ) async {
    final controller = GenesisColorController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      GenesisColorScope(
        controller: controller,
        child: MaterialApp(
          theme: GenesisTheme.light(),
          home: const DeveloperColorConfigurationPage(),
        ),
      ),
    );
    final surfaceTile = find.byKey(
      const ValueKey<String>('developer-color-token-surface.page'),
    );

    await tester.tap(surfaceTile);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '010203');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(
      controller.colorFor(Brightness.light, GenesisColorToken.surface),
      GenesisColorDefaults.light.color(GenesisColorToken.surface),
    );

    await tester.tap(surfaceTile);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '010203');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(
      controller.colorFor(Brightness.light, GenesisColorToken.surface),
      const Color(0xFF010203),
    );
  });
}
