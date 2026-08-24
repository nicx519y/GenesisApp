import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  testWidgets('compact group name uses the space before Empty', (tester) async {
    const groupName = 'Student Council Room';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 560,
            child: WorldLocationList(
              points: <WorldPoint>[],
              locationNodes: <WorldMapLocationNode>[
                WorldMapLocationNode(
                  id: 'group',
                  point: WorldPoint(
                    id: 'group',
                    name: groupName,
                    type: WorldPointType.castle,
                    position: Offset.zero,
                    users: <UserAvatar>[],
                    isLeafLocation: false,
                  ),
                  children: <WorldMapLocationNode>[
                    WorldMapLocationNode(
                      id: 'child',
                      point: WorldPoint(
                        id: 'child',
                        name: 'Meeting Room',
                        type: WorldPointType.castle,
                        position: Offset.zero,
                        users: <UserAvatar>[],
                      ),
                    ),
                  ],
                ),
              ],
              compactSheetStyle: true,
              enableOuterScrollHandoff: false,
            ),
          ),
        ),
      ),
    );

    final nameParagraph = tester.renderObject<RenderParagraph>(
      find.text(groupName),
    );
    expect(nameParagraph.didExceedMaxLines, isFalse);
    expect(
      tester.getRect(find.text(groupName)).right,
      lessThan(tester.getRect(find.text('1 place · Empty')).left),
    );
  });

  testWidgets('compact tree hangs one 5d-style guide per L2 block', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 800,
            child: WorldLocationList(
              points: <WorldPoint>[],
              locationNodes: <WorldMapLocationNode>[
                WorldMapLocationNode(
                  id: 'zone',
                  point: WorldPoint(
                    id: 'zone',
                    name: 'Ashford Estate',
                    type: WorldPointType.castle,
                    position: Offset.zero,
                    users: <UserAvatar>[],
                    isLeafLocation: false,
                  ),
                  children: <WorldMapLocationNode>[
                    WorldMapLocationNode(
                      id: 'main-house',
                      point: WorldPoint(
                        id: 'main-house',
                        name: 'The Main House',
                        type: WorldPointType.castle,
                        position: Offset.zero,
                        users: <UserAvatar>[],
                        isLeafLocation: false,
                      ),
                      children: <WorldMapLocationNode>[
                        WorldMapLocationNode(
                          id: 'ballroom',
                          point: WorldPoint(
                            id: 'ballroom',
                            name: 'Grand Ballroom',
                            type: WorldPointType.castle,
                            position: Offset.zero,
                            users: <UserAvatar>[],
                          ),
                        ),
                      ],
                    ),
                    WorldMapLocationNode(
                      id: 'east-wing',
                      point: WorldPoint(
                        id: 'east-wing',
                        name: 'The East Wing',
                        type: WorldPointType.castle,
                        position: Offset.zero,
                        users: <UserAvatar>[],
                        isLeafLocation: false,
                      ),
                      children: <WorldMapLocationNode>[
                        WorldMapLocationNode(
                          id: 'library',
                          point: WorldPoint(
                            id: 'library',
                            name: 'The Library',
                            type: WorldPointType.castle,
                            position: Offset.zero,
                            users: <UserAvatar>[],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
              compactSheetStyle: true,
              enableOuterScrollHandoff: false,
            ),
          ),
        ),
      ),
    );

    // L1 15/600,L2、L3 13/600。
    for (final (name, size) in [
      ('Ashford Estate', 15.0),
      ('The Main House', 13.0),
      ('Grand Ballroom', 13.0),
    ]) {
      final text = tester.widget<Text>(find.text(name));
      expect(text.style!.fontSize, size, reason: name);
      expect(text.style!.fontWeight, FontWeight.w600, reason: name);
    }

    bool hasGuide(String name) => find
        .ancestor(of: find.text(name), matching: find.byType(DecoratedBox))
        .evaluate()
        .any((element) {
          final decoration =
              (element.widget as DecoratedBox).decoration as BoxDecoration;
          return decoration.border is Border &&
              (decoration.border! as Border).left.width == 1;
        });

    // L1 无线;L2 头与 L3 行挂同一条 1px 线。
    expect(hasGuide('Ashford Estate'), isFalse);
    expect(hasGuide('The Main House'), isTrue);
    expect(hasGuide('Grand Ballroom'), isTrue);

    // 两个 L2 块之间有 12px 无线空隙(断点):
    // 上一块的末行底边到下一块 L2 头的线顶差 12。
    Rect guideRect(String name) => tester.getRect(
      find
          .ancestor(of: find.text(name), matching: find.byType(DecoratedBox))
          .last,
    );
    final firstBlockLeaf = guideRect('Grand Ballroom');
    final secondBlockHead = guideRect('The East Wing');
    expect(secondBlockHead.top - firstBlockLeaf.bottom, closeTo(12, 0.01));
    // 断点两侧的线落在同一 x 上。
    expect(secondBlockHead.left, firstBlockLeaf.left);

    // 计数只在 L1 上:地点数 + 在场人数。
    expect(find.text('2 places · Empty'), findsOneWidget);
    expect(find.text('Empty'), findsNothing);
  });
}
