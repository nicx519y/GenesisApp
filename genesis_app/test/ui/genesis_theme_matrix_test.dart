import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/theme/worldo_theme.dart';
import 'package:genesis_flutter_android/components/genesis_feature_themes.dart';
import 'package:genesis_flutter_android/ui/genesis_ui.dart';

void main() {
  for (final platform in <TargetPlatform>[
    TargetPlatform.android,
    TargetPlatform.iOS,
  ]) {
    for (final brightness in <Brightness>[Brightness.light, Brightness.dark]) {
      for (final textScale in <double>[1, 2]) {
        testWidgets(
          '${platform.name} ${brightness.name} keeps page chrome usable at ${textScale}x text',
          (tester) async {
            final controller = TextEditingController();
            addTearDown(controller.dispose);
            await tester.pumpWidget(
              MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
                child: MaterialApp(
                  theme: _themeFor(brightness, platform),
                  home: DefaultTabController(
                    length: 2,
                    child: GenesisPageScaffold.secondary(
                      title: 'Accessible Worldo settings',
                      actions: [
                        GenesisControlButton(
                          tooltip: 'More actions',
                          onPressed: () {},
                          child: const Icon(Icons.more_horiz, size: 14),
                        ),
                      ],
                      body: ListView(
                        children: [
                          GenesisSearchField.editable(
                            controller: controller,
                            hintText: 'Search worlds',
                            onClear: controller.clear,
                          ),
                          const SizedBox(height: 12),
                          const GenesisTabBar(labels: ['Overview', 'Members']),
                          const SizedBox(height: 20),
                          const Text('World settings and member controls'),
                          const SizedBox(height: 20),
                          GenesisPrimaryButton(
                            label: 'Save changes',
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pump();

            final context = tester.element(find.text('Save changes'));
            expect(Theme.of(context).brightness, brightness);
            expect(
              context.genesisColors,
              GenesisSemanticColors.forBrightness(brightness),
            );
            expect(Theme.of(context).extension<GenesisChatTheme>(), isNotNull);
            expect(find.text('Accessible Worldo settings'), findsOneWidget);
            expect(find.text('Save changes'), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}

ThemeData _themeFor(Brightness brightness, TargetPlatform platform) {
  final theme = brightness == Brightness.dark
      ? WorldoTheme.dark()
      : WorldoTheme.light();
  return theme.copyWith(platform: platform);
}
