import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/origin/origin_role_launch_sheet.dart';
import 'package:genesis_flutter_android/network/models/origin.dart';

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
}
