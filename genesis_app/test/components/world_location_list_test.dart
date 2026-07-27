import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/world_location_list.dart';
import 'package:genesis_flutter_android/components/world_point.dart';
import 'package:genesis_flutter_android/ui/genesis_ui.dart';

void main() {
  testWidgets('WorldLocationList uses layered Dark semantic colors', (
    tester,
  ) async {
    const point = WorldPoint(
      id: 'location-1',
      sceneId: 'location-1',
      name: 'Moon Harbor',
      type: WorldPointType.portal,
      position: Offset.zero,
      users: <UserAvatar>[
        UserAvatar('A', name: 'Aster'),
        UserAvatar('L', name: 'Luna', showStar: true),
      ],
      locationDescription: 'A quiet harbor beneath two moons.',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.dark(),
        home: const Scaffold(
          body: SizedBox(
            height: 220,
            child: WorldLocationList(
              points: <WorldPoint>[point],
              enableOuterScrollHandoff: false,
            ),
          ),
        ),
      ),
    );

    final dark = GenesisColorDefaults.dark;
    final title = tester.widget<Text>(find.text('Moon Harbor'));
    final aiNames = tester.widget<Text>(find.text('Luna'));
    final playerNames = tester.widget<Text>(find.text('Aster'));
    final description = tester.widget<Text>(
      find.text('A quiet harbor beneath two moons.'),
    );
    final locationIcon = tester.widget<Icon>(find.byIcon(Icons.place_outlined));
    final hasDarkListBackground = tester
        .widgetList<ColoredBox>(
          find.descendant(
            of: find.byType(WorldLocationList),
            matching: find.byType(ColoredBox),
          ),
        )
        .any((box) => box.color == dark.color(GenesisColorToken.surface));

    expect(hasDarkListBackground, isTrue);
    expect(title.style?.color, dark.color(GenesisColorToken.textPrimary));
    expect(
      aiNames.style?.color,
      dark.color(GenesisColorToken.textSecondaryStrong),
    );
    expect(
      playerNames.style?.color,
      dark.color(GenesisColorToken.textSecondaryStrong),
    );
    expect(
      description.style?.color,
      dark.color(GenesisColorToken.textMetadata),
    );
    expect(locationIcon.color, dark.color(GenesisColorToken.textLink));
  });
}
