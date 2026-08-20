import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/world_map_location_marker.dart';
import 'package:genesis_flutter_android/components/world_point.dart';
import 'package:genesis_flutter_android/ui/components/genesis_character_avatar.dart';

void main() {
  Widget harness({
    required List<UserAvatar> avatars,
    int eventCount = 0,
    bool highlighted = false,
    VoidCallback? onLabelTap,
    VoidCallback? onAvatarTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) {
              final metrics = resolveWorldMapLocationMarkerMetrics(
                context,
                name: 'Grand Ballroom',
                avatarCount: avatars.length,
              );
              return WorldMapLocationMarker(
                name: 'Grand Ballroom',
                avatars: avatars,
                eventCount: eventCount,
                highlighted: highlighted,
                metrics: metrics,
                onLabelTap: onLabelTap,
                onAvatarTap: onAvatarTap,
              );
            },
          ),
        ),
      ),
    );
  }

  testWidgets('uses the shared glass marker and preserves both tap targets', (
    tester,
  ) async {
    var labelTaps = 0;
    var avatarTaps = 0;
    await tester.pumpWidget(
      harness(
        avatars: const <UserAvatar>[
          UserAvatar('AA', id: 'a', name: 'Ada', isPlayerControlledRole: true),
        ],
        highlighted: true,
        onLabelTap: () => labelTaps += 1,
        onAvatarTap: () => avatarTaps += 1,
      ),
    );

    expect(find.byType(BackdropFilter), findsOneWidget);
    final pill = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('world-map-location-marker-pill')),
    );
    final decoration = pill.decoration as BoxDecoration;
    expect(decoration.color, worldMapLocationMarkerBackground);
    expect(decoration.border?.top.color.a, closeTo(0.62, 0.001));
    final avatar = tester.widget<GenesisCharacterAvatar>(
      find.byKey(const ValueKey<String>('world-map-location-marker-avatar-a')),
    );
    final avatarBorder = avatar.border! as Border;
    expect(avatarBorder.top.color, worldMapLocationMarkerEventColor);
    expect(avatarBorder.top.width, 2);

    await tester.tap(find.text('Grand Ballroom'));
    await tester.pump();
    expect(labelTaps, 1);

    await tester.tap(
      find.byKey(const ValueKey<String>('world-map-location-marker-avatar-a')),
    );
    await tester.pump();
    expect(avatarTaps, 1);
  });

  testWidgets('shows at most three faces and folds the rest into +N', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        avatars: const <UserAvatar>[
          UserAvatar('A', id: 'a'),
          UserAvatar('B', id: 'b'),
          UserAvatar('C', id: 'c'),
          UserAvatar('D', id: 'd'),
          UserAvatar('E', id: 'e'),
        ],
      ),
    );

    expect(find.byType(GenesisCharacterAvatar), findsNWidgets(3));
    expect(find.text('+2'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('world-map-location-marker-avatar-d')),
      findsNothing,
    );
  });

  testWidgets('renders the event total as a red numeric badge', (tester) async {
    await tester.pumpWidget(
      harness(avatars: const <UserAvatar>[], eventCount: 7),
    );

    expect(
      find.byKey(const ValueKey<String>('world-map-location-event-count')),
      findsOneWidget,
    );
    expect(find.text('7'), findsOneWidget);
  });
}
