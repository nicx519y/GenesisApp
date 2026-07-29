import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/world_location_list.dart';
import 'package:genesis_flutter_android/components/world_point.dart';
import 'package:genesis_flutter_android/ui/components/genesis_static_network_image.dart';

void main() {
  const networkPoint = WorldPoint(
    id: 'location-1',
    name: 'Location',
    type: WorldPointType.castle,
    position: Offset.zero,
    users: <UserAvatar>[],
    iconUrl: 'https://cdn.example.com/location.png?old=true#fragment',
  );

  for (final entry in const <(double, int)>[
    (1, 90),
    (2, 180),
    (3, 360),
    (4, 360),
  ]) {
    testWidgets(
      'location cover selects ${entry.$2}px image at DPR ${entry.$1}',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(devicePixelRatio: entry.$1),
              child: const Scaffold(
                body: WorldLocationList(
                  points: <WorldPoint>[networkPoint],
                  enableOuterScrollHandoff: false,
                ),
              ),
            ),
          ),
        );

        final image = tester.widget<GenesisStaticNetworkImage>(
          find.byType(GenesisStaticNetworkImage),
        );
        expect(
          image.imageUrl,
          'https://cdn.example.com/location.png'
          '?x-oss-process=image/resize,w_${entry.$2},image/format,webp',
        );
        expect(image.width, 64);
        expect(image.height, 64);
      },
    );
  }

  testWidgets('location cover preserves local assets', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WorldLocationList(
            points: <WorldPoint>[
              WorldPoint(
                id: 'location-asset',
                name: 'Asset Location',
                type: WorldPointType.castle,
                position: Offset.zero,
                users: <UserAvatar>[],
                iconUrl: 'assets/images/map_default/location_default.webp',
              ),
            ],
            enableOuterScrollHandoff: false,
          ),
        ),
      ),
    );

    expect(
      find.image(
        const AssetImage('assets/images/map_default/location_default.webp'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('location cover maps backend defaults to local assets', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WorldLocationList(
            points: <WorldPoint>[
              WorldPoint(
                id: 'location-backend-default',
                name: 'Default Location',
                type: WorldPointType.castle,
                position: Offset.zero,
                users: <UserAvatar>[],
                iconUrl:
                    'https://cdn-001.worldo.ai/predata/location_default.webp',
              ),
            ],
            enableOuterScrollHandoff: false,
          ),
        ),
      ),
    );

    expect(
      find.image(
        const AssetImage('assets/images/map_default/location_default.webp'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('location cover uses the location placeholder when empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WorldLocationList(
            points: <WorldPoint>[
              WorldPoint(
                id: 'location-empty',
                name: 'Empty Location',
                type: WorldPointType.castle,
                position: Offset.zero,
                users: <UserAvatar>[],
              ),
            ],
            enableOuterScrollHandoff: false,
          ),
        ),
      ),
    );

    expect(
      find.image(
        const AssetImage('assets/images/map_default/location_default.webp'),
      ),
      findsOneWidget,
    );
  });
}
