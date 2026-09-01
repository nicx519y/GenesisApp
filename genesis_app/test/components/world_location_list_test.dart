import 'dart:convert';

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
    (3, 180),
    (4, 180),
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

  testWidgets('location cover prefers local preview bytes over network URL', (
    tester,
  ) async {
    final previewBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
      'YAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 2),
          child: Scaffold(
            body: WorldLocationList(
              points: <WorldPoint>[
                WorldPoint(
                  id: 'location-local-preview',
                  name: 'Local Preview',
                  type: WorldPointType.castle,
                  position: Offset.zero,
                  users: const <UserAvatar>[],
                  iconUrl: 'https://cdn.example.com/location.png',
                  iconBytes: previewBytes,
                ),
              ],
              enableOuterScrollHandoff: false,
            ),
          ),
        ),
      ),
    );

    final memoryImage = find.byKey(
      const ValueKey<String>(
        'world-location-memory-image-location-local-preview',
      ),
    );
    expect(memoryImage, findsOneWidget);
    final image = tester.widget<Image>(memoryImage);
    expect(image.image, isA<ResizeImage>());
    expect((image.image as ResizeImage).width, 128);
    expect(find.byType(GenesisStaticNetworkImage), findsNothing);
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

  testWidgets('location rows are built lazily while scrolling', (tester) async {
    final points = List<WorldPoint>.generate(
      80,
      (index) => WorldPoint(
        id: 'location-$index',
        name: 'Location $index',
        type: WorldPointType.castle,
        position: Offset.zero,
        users: const <UserAvatar>[],
      ),
      growable: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 220,
            child: WorldLocationList(
              points: points,
              enableOuterScrollHandoff: false,
              lazyBuildRows: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Location 0'), findsOneWidget);
    expect(find.text('Location 79'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Location 79'),
      500,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Location 79'), findsOneWidget);
  });

  testWidgets('new location badge is shown for flat, branch, and leaf rows', (
    tester,
  ) async {
    const newFlat = WorldPoint(
      id: 'new-flat',
      name: 'New Flat',
      type: WorldPointType.castle,
      position: Offset.zero,
      users: <UserAvatar>[],
      isNew: true,
    );
    const oldFlat = WorldPoint(
      id: 'old-flat',
      name: 'Old Flat',
      type: WorldPointType.castle,
      position: Offset.zero,
      users: <UserAvatar>[],
    );
    const newBranchPoint = WorldPoint(
      id: 'new-branch',
      name: 'New Branch',
      type: WorldPointType.castle,
      position: Offset.zero,
      users: <UserAvatar>[],
      isLeafLocation: false,
      isNew: true,
    );
    const newLeafPoint = WorldPoint(
      id: 'new-leaf',
      name: 'New Leaf',
      type: WorldPointType.castle,
      position: Offset.zero,
      users: <UserAvatar>[],
      isNew: true,
    );
    const oldLeafPoint = WorldPoint(
      id: 'old-leaf',
      name: 'Old Leaf',
      type: WorldPointType.castle,
      position: Offset.zero,
      users: <UserAvatar>[],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: WorldLocationList(
                  points: <WorldPoint>[newFlat, oldFlat],
                  enableOuterScrollHandoff: false,
                ),
              ),
              Expanded(
                child: WorldLocationList(
                  points: <WorldPoint>[],
                  locationNodes: <WorldMapLocationNode>[
                    WorldMapLocationNode(
                      id: 'new-branch',
                      point: newBranchPoint,
                      children: <WorldMapLocationNode>[
                        WorldMapLocationNode(
                          id: 'new-leaf',
                          point: newLeafPoint,
                        ),
                        WorldMapLocationNode(
                          id: 'old-leaf',
                          point: oldLeafPoint,
                        ),
                      ],
                    ),
                  ],
                  enableOuterScrollHandoff: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('world-location-new-badge-new-flat')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('world-location-new-badge-new-branch')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('world-location-new-badge-new-leaf')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('world-location-new-badge-old-flat')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('world-location-new-badge-old-leaf')),
      findsNothing,
    );
  });

  testWidgets('new character badge is shown beside the character name', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WorldLocationList(
            points: <WorldPoint>[
              WorldPoint(
                id: 'location-with-characters',
                name: 'Location',
                type: WorldPointType.castle,
                position: Offset.zero,
                users: <UserAvatar>[
                  UserAvatar(
                    'NC',
                    id: 'new-character',
                    name: 'New Character',
                    isNew: true,
                  ),
                  UserAvatar('OC', id: 'old-character', name: 'Old Character'),
                ],
              ),
            ],
            enableOuterScrollHandoff: false,
          ),
        ),
      ),
    );

    expect(
      find.byKey(
        const ValueKey('world-location-character-new-badge-new-character'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('world-location-character-new-badge-old-character'),
      ),
      findsNothing,
    );
  });
}
