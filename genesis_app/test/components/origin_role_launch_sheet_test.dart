import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/origin/origin_role_launch_sheet.dart';
import 'package:genesis_flutter_android/network/models/origin.dart';
import 'package:genesis_flutter_android/ui/components/genesis_primary_button.dart';

void main() {
  testWidgets('initial launched tab is visible before roles finish loading', (
    WidgetTester tester,
  ) async {
    final rolesCompleter = Completer<List<OriginMyLaunchPresetCharacter>>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OriginRoleLaunchSheet(
            characters: const [
              OriginCharacter(
                id: 1,
                characterId: 'preset_1',
                originId: 1,
                name: 'Preset role',
                avatar: '',
                tags: '',
                currentLocationId: 0,
                initialLocationId: 0,
                createdAt: null,
                updatedAt: null,
              ),
            ],
            initialLaunchedTab: true,
            launchedPresetRolesLoader: () => rolesCompleter.future,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const ValueKey('origin-role-preset-tab')), findsNothing);

    rolesCompleter.complete(const <OriginMyLaunchPresetCharacter>[]);
    await tester.pumpAndSettle();

    expect(find.text('No launched role'), findsOneWidget);
    expect(find.byKey(const ValueKey('origin-role-preset-tab')), findsNothing);
  });

  testWidgets('route keeps the requested transparent status bar style', (
    WidgetTester tester,
  ) async {
    const style = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => unawaited(
                showOriginRoleLaunchSheet(
                  context: context,
                  characters: const <OriginCharacter>[],
                  systemUiOverlayStyle: style,
                ),
              ),
              child: const Text('Show setup'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show setup'));
    await tester.pump();

    expect(
      tester
          .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          )
          .any((region) => region.value == style),
      isTrue,
    );
  });

  testWidgets('launch stays in the sheet and shows button loading', (
    WidgetTester tester,
  ) async {
    var launchCompleter = Completer<bool>();
    OriginRoleLaunchSelection? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showOriginRoleLaunchSheet(
                  context: context,
                  characters: const [
                    OriginCharacter(
                      id: 1,
                      characterId: 'preset_1',
                      originId: 1,
                      name: 'Preset role',
                      avatar: '',
                      tags: '',
                      currentLocationId: 0,
                      initialLocationId: 0,
                      createdAt: null,
                      updatedAt: null,
                    ),
                  ],
                  onLaunch: (_) => launchCompleter.future,
                );
              },
              child: const Text('Show setup'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show setup'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('origin-role-preset-preset_1')));
    await tester.tap(find.byKey(const ValueKey('origin-role-launch')));
    await tester.pump();

    expect(find.byKey(const ValueKey('origin-role-sheet')), findsOneWidget);
    expect(
      tester
          .widget<GenesisPrimaryButton>(
            find.byKey(const ValueKey('origin-role-launch')),
          )
          .isLoading,
      isTrue,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.descendant(
              of: find.byKey(const ValueKey('origin-role-cancel')),
              matching: find.byType(OutlinedButton),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.descendant(
              of: find.byKey(const ValueKey('origin-role-sheet-close')),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );

    launchCompleter.complete(false);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('origin-role-sheet')), findsOneWidget);
    expect(
      tester
          .widget<GenesisPrimaryButton>(
            find.byKey(const ValueKey('origin-role-launch')),
          )
          .isLoading,
      isFalse,
    );

    launchCompleter = Completer<bool>();
    await tester.tap(find.byKey(const ValueKey('origin-role-launch')));
    await tester.pump();
    launchCompleter.complete(true);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('origin-role-sheet')), findsNothing);
    expect(result?.presetCharacterId, 'preset_1');
  });
}
