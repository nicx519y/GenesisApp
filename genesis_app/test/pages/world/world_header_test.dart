import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/world.dart';
import 'package:genesis_flutter_android/pages/world/world_constants.dart';
import 'package:genesis_flutter_android/pages/world/world_header.dart';
import 'package:genesis_flutter_android/pages/world/world_models.dart';
import 'package:genesis_flutter_android/ui/components/genesis_control_icons.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_semantic_colors.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_typography.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

void main() {
  test('world map time label includes the current sub-tick number', () {
    expect(
      worldTimeLabel(tickIndex: 7, subTickNo: 3, worldTime: 'Day 45, 19:30'),
      'Tick 7-3 · Day 45, 19:30',
    );
  });

  test('world map time label keeps sub-tick when tick number is zero', () {
    expect(
      worldTimeLabel(tickIndex: 0, subTickNo: 3, worldTime: 'Day 1, 20:25'),
      'Tick 0-3 · Day 1, 20:25',
    );
  });

  test('world detail reads an explicit sub-tick for tick number zero', () {
    final world = WorldDetail.fromJson(const {
      'world_id': 'world-0',
      'tick_count': 0,
      'sub_tick_no': 3,
    });

    expect(world.subTickNo, 3);
  });

  test('world detail does not derive a missing sub-tick from ticks', () {
    final world = WorldDetail.fromJson(const {
      'world_id': 'world-1',
      'tick_count': 7,
      'ticks': [
        {'tick_no': 7, 'sub_tick_no': 3},
      ],
    });

    expect(world.subTickNo, 0);
  });

  test('world preview status reads Not started', () {
    expect(
      worldMapStatusLabel(
        relationStatus: 'anonymous',
        timeText: 'Tick 3 · Day 2, 01:00',
      ),
      'Not started',
    );
  });

  testWidgets('world map title bar matches the redesigned hierarchy', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoLight(),
        home: Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WorldMapBackButton(onPressed: () {}),
              const SizedBox(width: worldMapHeaderTitleGap),
              const WorldMapIdentityPill(
                title: 'Old Money',
                statusText: 'Not started',
                maxWidth: 240,
              ),
            ],
          ),
        ),
      ),
    );

    final backButtonFinder = find.byKey(
      const ValueKey<String>('world-map-back-button'),
    );
    expect(tester.getSize(backButtonFinder), const Size.square(34));
    final backIcon = tester.widget<GenesisBackIcon>(
      find.descendant(
        of: backButtonFinder,
        matching: find.byType(GenesisBackIcon),
      ),
    );
    expect(backIcon.size, 14);

    final title = tester.widget<Text>(
      find.byKey(const ValueKey<String>('world-map-title')),
    );
    expect(title.data, 'Old Money');
    expect(title.style?.fontSize, GenesisTypography.immersiveTitle.fontSize);
    expect(title.style?.height, GenesisTypography.immersiveTitle.height);
    expect(title.style?.fontWeight, FontWeight.w800);
    expect(
      title.style?.color,
      GenesisSemanticColors.worldoLight().immersiveForeground,
    );

    final status = tester.widget<Text>(
      find.byKey(const ValueKey<String>('world-map-status')),
    );
    expect(status.data, 'Not started');
    expect(status.style?.fontSize, 9.5);
    expect(status.style?.height, 1.4);
    expect(status.style?.fontWeight, FontWeight.w600);
    expect(
      status.style?.color,
      GenesisSemanticColors.worldoLight().immersiveForeground.withValues(
        alpha: 0.73,
      ),
    );
  });

  testWidgets('joined world panel matches the active-role resting layout', (
    tester,
  ) async {
    var actionCount = 0;
    WorldHeaderActionKind? lastAction;
    final world = WorldDetail.fromJson(const {
      'world_id': 'world-resting',
      'relation_status': 'joined',
      'tick_count': 7,
      'sub_tick_no': 2,
      'characters': [
        {'name': 'Adrian', 'avatar': '', 'player_uid': 'user-me'},
      ],
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoDark(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: 390,
              child: WorldInfoHeader(
                world: world,
                currentUid: 'user-me',
                worldActionRunning: false,
                onWorldAction: (action) async {
                  actionCount++;
                  lastAction = action;
                },
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('world-playing-avatar'))),
      const Size.square(worldCharacterAvatarLogicalSize),
    );
    expect(find.text('Playing Adrian'), findsOneWidget);
    expect(find.text('Tick 7-2'), findsOneWidget);
    expect(find.text('Tick now'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('world-action-button'))),
      const Size(92, worldInfoHeaderContentHeight),
    );

    await tester.tap(find.text('Tick now'));
    await tester.pump();

    expect(actionCount, 1);
    expect(lastAction, WorldHeaderActionKind.progress);
  });
}
