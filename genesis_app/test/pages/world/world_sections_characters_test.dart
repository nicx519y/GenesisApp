import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/origin.dart';
import 'package:genesis_flutter_android/network/models/world.dart';
import 'package:genesis_flutter_android/pages/world/world_sections.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_palette.dart';

void main() {
  testWidgets('status shows You, metric progress, and current location name', (
    tester,
  ) async {
    final world = _worldDetail();

    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoRedesign(),
        home: Scaffold(
          body: WorldStatusSection(world: world, currentUid: 'user-me'),
        ),
      ),
    );

    expect(_richText('Adrian You'), findsOneWidget);
    expect(_richText('Adrian (Me)'), findsNothing);
    expect(find.text('56%'), findsOneWidget);
    expect(find.text('Grand Ballroom'), findsOneWidget);

    final progress = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey<String>('world-status-progress-character-me')),
    );
    expect(progress.value, 0.56);
  });

  testWidgets(
    'small positive status progress stays visibly distinct from zero',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: GenesisTheme.worldoRedesign(),
          home: Scaffold(
            body: WorldStatusSection(
              world: _worldDetail(metricValue: 3),
              currentUid: 'user-me',
            ),
          ),
        ),
      );

      expect(find.text('3%'), findsOneWidget);
      final progressFinder = find.byKey(
        const ValueKey<String>('world-status-progress-character-me'),
      );
      final progress = tester.widget<LinearProgressIndicator>(progressFinder);
      final trackWidth = tester.getSize(progressFinder).width;

      expect(progress.semanticsValue, '3%');
      expect(progress.value, greaterThan(0.03));
      expect(progress.value! * trackWidth, greaterThanOrEqualTo(12));
    },
  );

  testWidgets('zero status progress still has no visible fill', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoRedesign(),
        home: Scaffold(
          body: WorldStatusSection(
            world: _worldDetail(metricValue: 0),
            currentUid: 'user-me',
          ),
        ),
      ),
    );

    final progress = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey<String>('world-status-progress-character-me')),
    );
    expect(progress.value, 0);
    expect(find.text('0%'), findsOneWidget);
  });

  testWidgets('detail character content uses the design hierarchy colors', (
    tester,
  ) async {
    const identity =
        'The brilliant young heir of a rival empire, courting her like a hostile takeover.';
    const brief = 'Cold, polished, and efficient without feeling.';
    const goal = 'Secure the Ashford merger, whatever it takes.';

    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoRedesign(),
        home: const Scaffold(
          body: WorldCharacterRow(
            character: <String, dynamic>{
              'char_id': 'adrian',
              'player_uid': '',
              'name': 'Adrian',
              'identity': identity,
              'brief': brief,
              'goal': goal,
            },
            currentUid: 'user-me',
            subtitle: '',
            subtitleColor: GenesisPalette.redesignWhite60,
            showCharacterDetails: true,
          ),
        ),
      ),
    );

    expect(
      tester.widget<Text>(find.text(identity)).style?.color,
      GenesisPalette.white.withValues(alpha: 0.92),
    );
    expect(
      tester.widget<Text>(find.text(brief)).style?.color,
      GenesisPalette.redesignAccentSoft,
    );

    final goalText = tester.widget<Text>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text && widget.textSpan?.toPlainText() == 'Goal: $goal',
      ),
    );
    final goalSpan = goalText.textSpan! as TextSpan;
    expect(goalSpan.style?.color, GenesisPalette.redesignWhite72);
    final labelSpan = goalSpan.children!.first as TextSpan;
    expect(labelSpan.style?.color, GenesisPalette.white);
    expect(labelSpan.style?.fontWeight, FontWeight.w600);
  });
}

Finder _richText(String text) {
  return find.byWidgetPredicate(
    (widget) => widget is RichText && widget.text.toPlainText() == text,
    description: 'RichText "$text"',
  );
}

WorldDetail _worldDetail({num metricValue = 56}) {
  return WorldDetail(
    id: 1,
    worldId: 'world-cast-test',
    originId: 1,
    ownerUid: 'owner',
    name: 'Cast Test',
    tickCount: 1,
    connectCount: 1,
    characterCount: 1,
    playerCount: 1,
    currentTime: '',
    latestTickAt: null,
    latestNarrator: '',
    isProgressing: false,
    relationStatus: 'joined',
    metric: const <String, dynamic>{
      'label': 'Goal Progress',
      'unit': '%',
      'range': <int>[0, 100],
      'default': 0,
    },
    inviteToken: '',
    createdAt: null,
    updatedAt: null,
    origin: const OriginSummary(
      id: 1,
      oid: 'origin-cast-test',
      name: 'Origin',
      description: '',
      mapImage: '',
      worldMap: '',
      worldView: '',
      copyCount: 0,
      interactCount: 0,
      tags: <String>[],
      createdAt: null,
      updatedAt: null,
      characters: <OriginCharacter>[],
      locations: <OriginLocation>[],
    ),
    characters: <Map<String, dynamic>>[
      <String, dynamic>{
        'char_id': 'character-me',
        'player_uid': 'user-me',
        'player_username': 'Long',
        'name': 'Adrian',
        'avatar': '',
        'metric_value': metricValue,
      },
    ],
    ticks: const <Map<String, dynamic>>[],
    locations: const <Map<String, dynamic>>[
      <String, dynamic>{
        'location_id': 'location-ballroom',
        'location_name': 'Grand Ballroom',
      },
    ],
    characterPositions: const <Map<String, dynamic>>[],
    userPositions: const <Map<String, dynamic>>[
      <String, dynamic>{'uid': 'user-me', 'location_id': 'location-ballroom'},
    ],
  );
}
