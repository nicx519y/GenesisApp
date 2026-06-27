import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/world_details_shell.dart';
import 'package:genesis_flutter_android/components/world_map.dart';
import 'package:genesis_flutter_android/components/world_map_interaction_notification.dart';
import 'package:genesis_flutter_android/icons/custom_icon_assets.dart';
import 'package:genesis_flutter_android/icons/my_flutter_app_icons.dart';
import 'package:genesis_flutter_android/network/mock_data/mock_v1_data.dart';
import 'package:genesis_flutter_android/pages/world/world_map_data.dart';
import 'package:genesis_flutter_android/ui/components/genesis_character_avatar.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  test('mock world data includes dense map points and default map asset', () {
    expect(kMockV1Locations.length, greaterThanOrEqualTo(9));

    final countsByLocation = <String, int>{};
    for (final character in kMockV1Characters) {
      final locationId = '${character['location_id']}';
      countsByLocation[locationId] = (countsByLocation[locationId] ?? 0) + 1;
    }

    expect(countsByLocation['loc_hub'], 3);
    expect(countsByLocation['loc_gate'], greaterThanOrEqualTo(4));
    expect(countsByLocation['loc_market'], greaterThanOrEqualTo(5));
    expect(
      File('assets/images/map_default/root_default.webp').existsSync(),
      isTrue,
      reason: 'assets/images/map_default/root_default.webp',
    );
    for (final origin in kMockV1Origins) {
      expect(origin['cover'], isEmpty);
    }
    for (final world in kMockV1Worlds) {
      expect(world['cover'], isEmpty);
    }

    final avatarPaths = kMockV1Characters
        .map((character) => '${character['avatar']}')
        .where((path) => path.startsWith('assets/images/mock_avatars/'))
        .toSet();
    expect(avatarPaths, isEmpty);

    final locationCoverPaths = kMockV1Locations
        .map((location) => '${location['image']}')
        .where((path) => path.startsWith('assets/images/mock_locations/'))
        .toSet();
    expect(locationCoverPaths, isEmpty);

    final locationMapPaths = kMockV1Locations
        .map((location) => '${location['map_url']}')
        .where((path) => path.startsWith('assets/images/map_default/'))
        .toSet();
    expect(locationMapPaths, isEmpty);
  });

  testWidgets('world map lays out fewer than four avatars in one row', (
    tester,
  ) async {
    await _pumpWorldMap(
      tester,
      mapImageUrl: kMockV1SteamMapImage,
      users: const [
        UserAvatar(
          'AA',
          name: 'Ada',
          avatarUrl: 'assets/images/default_list_image.png',
          showStar: true,
        ),
        UserAvatar(
          'BB',
          name: 'Bert',
          avatarUrl: 'assets/images/default_list_image.png',
        ),
        UserAvatar(
          'CC',
          name: 'Cy',
          avatarUrl: 'assets/images/default_list_image.png',
        ),
      ],
    );

    final avatars = find.byType(GenesisCharacterAvatar);
    expect(avatars, findsNWidgets(3));
    expect(tester.getSize(avatars.first), const Size(42, 42));
    expect(
      tester.widget<GenesisCharacterAvatar>(avatars.first).boxShadow,
      isNotEmpty,
    );
    expect(find.byIcon(MyFlutterApp.redstarCharIcon), findsOneWidget);

    final first = tester.getTopLeft(avatars.at(0));
    final second = tester.getTopLeft(avatars.at(1));
    final third = tester.getTopLeft(avatars.at(2));
    expect(second.dy, first.dy);
    expect(third.dy, first.dy);
    expect(second.dx, greaterThan(first.dx));
    expect(third.dx, greaterThan(second.dx));
  });

  testWidgets('world map renders generated avatar when avatar URL is empty', (
    tester,
  ) async {
    await _pumpWorldMap(
      tester,
      users: const [UserAvatar('LP', id: 'larry-page', name: 'Larry Page')],
    );

    expect(find.byType(GenesisCharacterAvatar), findsOneWidget);
    expect(find.text('LP'), findsOneWidget);
  });

  testWidgets('world map shows bubble for matching visible avatar', (
    tester,
  ) async {
    await _pumpWorldMap(
      tester,
      users: const [UserAvatar('AA', id: 'char_a', name: 'Ava')],
      activeBubble: const WorldMapMessageBubble(
        characterId: 'char_a',
        content: 'Ava checks the storefront.',
      ),
    );

    expect(find.text('Ava checks the storefront.'), findsOneWidget);
  });

  testWidgets('world map hides bubble when avatar is not visible', (
    tester,
  ) async {
    await _pumpWorldMap(
      tester,
      users: const [UserAvatar('AA', id: 'char_a', name: 'Ava')],
      activeBubble: const WorldMapMessageBubble(
        characterId: 'char_b',
        content: 'Ben is elsewhere.',
      ),
    );

    expect(find.text('Ben is elsewhere.'), findsNothing);
  });

  test('player controlled map avatar uses highlighted border', () {
    expect(
      worldMapAvatarBorderColorForTesting(isPlayerControlledRole: true),
      const Color(0xFF338960),
    );
    expect(
      worldMapAvatarBorderColorForTesting(isPlayerControlledRole: false),
      const Color(0xFFDDDDDD),
    );
  });

  test('world map star only shows for unclaimed ai roles', () {
    expect(
      worldMapCharacterShouldShowStarForTesting({'type': 1, 'player_uid': ''}),
      isTrue,
    );
    expect(
      worldMapCharacterShouldShowStarForTesting({
        'type': 'ai',
        'player_uid': null,
      }),
      isTrue,
    );
    expect(
      worldMapCharacterShouldShowStarForTesting({
        'type': 1,
        'player_uid': 'u_1',
      }),
      isFalse,
    );
    expect(
      worldMapCharacterShouldShowStarForTesting({'type': 2, 'player_uid': ''}),
      isFalse,
    );
  });

  testWidgets(
    'world map moves point anchors with zoom without scaling markers',
    (tester) async {
      await _pumpWorldMap(
        tester,
        mapImageUrl: kMockV1SteamMapImage,
        users: const [
          UserAvatar(
            'AA',
            name: 'Ada',
            avatarUrl: 'assets/images/default_list_image.png',
          ),
        ],
      );

      final interactiveViewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );

      expect(interactiveViewer.minScale, 1);
      expect(interactiveViewer.maxScale, 2);
      expect(interactiveViewer.panEnabled, isTrue);
      expect(
        find.descendant(
          of: find.byType(InteractiveViewer),
          matching: find.byType(GenesisCharacterAvatar),
        ),
        findsNothing,
      );
      final avatar = find.byType(GenesisCharacterAvatar);
      expect(avatar, findsOneWidget);

      final initialAvatarTopLeft = tester.getTopLeft(avatar);
      final initialAvatarSize = tester.getSize(avatar);
      final first = await tester.createGesture(pointer: 1);
      final second = await tester.createGesture(pointer: 2);

      await first.down(const Offset(110, 520));
      await second.down(const Offset(250, 520));
      await tester.pump();
      await first.moveTo(const Offset(70, 560));
      await second.moveTo(const Offset(290, 480));
      await tester.pump();
      await second.up();
      await first.up();
      await tester.pump();

      expect(tester.getSize(avatar), initialAvatarSize);
      expect(tester.getTopLeft(avatar), isNot(initialAvatarTopLeft));
    },
  );

  testWidgets('world map pinches when both pointers start on map markers', (
    tester,
  ) async {
    await _pumpWorldMap(
      tester,
      mapImageUrl: kMockV1SteamMapImage,
      users: const [
        UserAvatar(
          'AA',
          name: 'Ada',
          avatarUrl: 'assets/images/default_list_image.png',
        ),
      ],
    );

    final avatar = find.byType(GenesisCharacterAvatar);
    expect(avatar, findsOneWidget);
    final initialAvatarTopLeft = tester.getTopLeft(avatar);
    final initialAvatarSize = tester.getSize(avatar);
    final avatarCenter = tester.getCenter(avatar);
    final first = await tester.createGesture(pointer: 1);
    final second = await tester.createGesture(pointer: 2);

    await first.down(avatarCenter - const Offset(8, 0));
    await second.down(avatarCenter + const Offset(8, 0));
    await tester.pump();
    await first.moveTo(avatarCenter - const Offset(44, 34));
    await second.moveTo(avatarCenter + const Offset(44, 34));
    await tester.pump();
    await second.up();
    await first.up();
    await tester.pump();

    expect(tester.getSize(avatar), initialAvatarSize);
    expect(tester.getTopLeft(avatar), isNot(initialAvatarTopLeft));
  });

  testWidgets('world map double tap toggles zoom around tap position', (
    tester,
  ) async {
    await _pumpWorldMap(
      tester,
      mapImageUrl: kMockV1SteamMapImage,
      users: const [
        UserAvatar(
          'AA',
          name: 'Ada',
          avatarUrl: 'assets/images/default_list_image.png',
        ),
      ],
    );

    final avatar = find.byType(GenesisCharacterAvatar);
    final initialAvatarTopLeft = tester.getTopLeft(avatar);
    final initialAvatarSize = tester.getSize(avatar);

    await tester.tapAt(const Offset(150, 520));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(const Offset(150, 520));
    await tester.pump();

    expect(tester.getSize(avatar), initialAvatarSize);
    expect(tester.getTopLeft(avatar), isNot(initialAvatarTopLeft));

    await tester.tapAt(const Offset(150, 520));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(const Offset(150, 520));
    await tester.pump();

    expect(tester.getSize(avatar), initialAvatarSize);
    expect(tester.getTopLeft(avatar), initialAvatarTopLeft);
  });

  testWidgets('world map notifies parent scrolling on second pointer down', (
    tester,
  ) async {
    final states = <bool>[];
    await _pumpWorldMap(
      tester,
      users: const [],
      onMapInteractionChanged: states.add,
    );

    final first = await tester.createGesture(pointer: 1);
    final second = await tester.createGesture(pointer: 2);
    await first.down(const Offset(100, 100));
    await second.down(const Offset(140, 140));
    await tester.pump();

    expect(states, contains(true));

    await second.up();
    await first.up();
    await tester.pump();

    expect(states.last, isFalse);
  });

  testWidgets('world map renders local asset map background', (tester) async {
    await _pumpWorldMap(
      tester,
      mapImageUrl: kWorldMapFallbackBackgroundAsset,
      users: const [],
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                kWorldMapFallbackBackgroundAsset,
      ),
      findsOneWidget,
    );
  });

  testWidgets('world map uses fallback background when map URL is empty', (
    tester,
  ) async {
    await _pumpWorldMap(tester, users: const []);

    expect(_assetImageFinder(kWorldMapFallbackBackgroundAsset), findsOneWidget);
  });

  testWidgets('world map can keep empty URL in loading placeholder state', (
    tester,
  ) async {
    await _pumpWorldMap(tester, users: const [], fallbackOnEmptyMapUrl: false);

    expect(_assetImageFinder(kWorldMapFallbackBackgroundAsset), findsNothing);
    expect(_mapPlaceholderFinder(), findsOneWidget);
  });

  testWidgets('world map uses fallback background when map asset fails', (
    tester,
  ) async {
    await _pumpWorldMap(
      tester,
      mapImageUrl: 'assets/images/map_default/missing_map.webp',
      users: const [],
    );
    await tester.pump();

    expect(_assetImageFinder(kWorldMapFallbackBackgroundAsset), findsOneWidget);
  });

  testWidgets(
    'world map scales to fill tall screens with horizontal overflow',
    (tester) async {
      const viewportSize = Size(375, 812);
      await _pumpWorldMap(
        tester,
        size: viewportSize,
        mapImageUrl: kMockV1SteamMapImage,
        users: const [],
      );
      await tester.pump();

      final scaledContent = find.byKey(
        const ValueKey<String>('world-map-scaled-content'),
      );
      final contentSize = tester.getSize(scaledContent);
      final contentTopLeft = tester.getTopLeft(scaledContent);

      expect(contentSize.height, viewportSize.height);
      expect(contentSize.width, closeTo(viewportSize.height * 375 / 670, 0.01));
      expect(contentSize.width, greaterThan(viewportSize.width));
      expect(contentTopLeft.dx, 0);
      expect(contentTopLeft.dy, 0);
    },
  );

  testWidgets('world map lays out four avatars in a two by two grid', (
    tester,
  ) async {
    await _pumpWorldMap(
      tester,
      users: const [
        UserAvatar(
          'AA',
          name: 'Ada',
          avatarUrl: 'assets/images/default_list_image.png',
        ),
        UserAvatar(
          'BB',
          name: 'Bert',
          avatarUrl: 'assets/images/default_list_image.png',
        ),
        UserAvatar(
          'CC',
          name: 'Cy',
          avatarUrl: 'assets/images/default_list_image.png',
        ),
        UserAvatar(
          'DD',
          name: 'Dee',
          avatarUrl: 'assets/images/default_list_image.png',
        ),
      ],
    );

    final avatars = find.byType(GenesisCharacterAvatar);
    expect(avatars, findsNWidgets(4));

    final topLeftAvatar = tester.getTopLeft(avatars.at(0));
    final topRightAvatar = tester.getTopLeft(avatars.at(1));
    final bottomLeftAvatar = tester.getTopLeft(avatars.at(2));
    final bottomRightAvatar = tester.getTopLeft(avatars.at(3));
    final pointY = _mapSize.height * _pointPosition.dy;

    expect(topLeftAvatar.dy, closeTo(pointY + 10, 0.01));
    expect(topRightAvatar.dy, topLeftAvatar.dy);
    expect(bottomLeftAvatar.dy, greaterThan(topLeftAvatar.dy));
    expect(bottomRightAvatar.dy, bottomLeftAvatar.dy);
    expect(topRightAvatar.dx, greaterThan(topLeftAvatar.dx));
    expect(bottomLeftAvatar.dx, topLeftAvatar.dx);
    expect(bottomRightAvatar.dx, topRightAvatar.dx);
  });

  testWidgets('world map allows slight avatar overlap for dense rings', (
    tester,
  ) async {
    await _pumpWorldMap(
      tester,
      users: const [
        UserAvatar('AA', name: 'Ada'),
        UserAvatar('BB', name: 'Bert'),
        UserAvatar('CC', name: 'Cy'),
        UserAvatar('DD', name: 'Dee'),
        UserAvatar('EE', name: 'Eli'),
        UserAvatar('FF', name: 'Flo'),
      ],
    );

    final avatars = find.byType(GenesisCharacterAvatar);
    expect(avatars, findsNWidgets(6));

    final firstCenter = tester.getCenter(avatars.at(0));
    final secondCenter = tester.getCenter(avatars.at(1));
    expect((firstCenter - secondCenter).distance, lessThan(42));
  });

  testWidgets('points list shows all locations and indents by hierarchy', (
    tester,
  ) async {
    await _pumpWorldMap(
      tester,
      users: const [],
      showPointsList: true,
      points: const [
        WorldPoint(
          id: 'root',
          name: 'Root Gate',
          type: WorldPointType.portal,
          position: _pointPosition,
          users: [],
          iconUrl: kMockV1SteamMapImage,
        ),
        WorldPoint(
          id: 'level-1',
          name: 'Rail Gate',
          type: WorldPointType.shop,
          position: _pointPosition,
          users: [
            UserAvatar('AA', name: 'Ada', showStar: true),
            UserAvatar('BB', name: 'Bert', showStar: true),
            UserAvatar('CC', name: 'Cara'),
            UserAvatar('DD', name: 'Drew'),
          ],
          iconUrl: kMockV1SteamMapImage,
          description: 'Gate checkpoint summary.',
          locationDescription: 'Gate checkpoint description.',
          depth: 1,
        ),
        WorldPoint(
          id: 'level-2',
          name: 'Airdock Nine',
          type: WorldPointType.camp,
          position: _pointPosition,
          users: [],
          iconUrl: kMockV1SteamMapImage,
          depth: 2,
        ),
      ],
    );

    final list = find.byType(ListView);
    expect(find.byType(WorldLocationList), findsOneWidget);
    final rootTitle = find.descendant(
      of: list,
      matching: find.text('Root Gate'),
    );
    final levelOneTitle = find.descendant(
      of: list,
      matching: find.text('Rail Gate'),
    );
    final levelTwoTitle = find.descendant(
      of: list,
      matching: find.text('Airdock Nine'),
    );

    expect(rootTitle, findsOneWidget);
    expect(levelOneTitle, findsOneWidget);
    expect(levelTwoTitle, findsOneWidget);
    expect(find.byType(Divider), findsNWidgets(2));
    expect(find.byIcon(Icons.place_outlined), findsNWidgets(3));
    expect(_assetSvgFinder(characterStatIconAsset), findsOneWidget);
    expect(_assetSvgFinder(userStatIconAsset), findsOneWidget);
    expect(find.byIcon(Icons.schedule), findsNothing);
    expect(find.text('Ada, Bert'), findsOneWidget);
    expect(find.text('Cara, Drew'), findsOneWidget);
    expect(find.text('Gate checkpoint description.'), findsOneWidget);
    expect(find.text('Gate checkpoint summary.'), findsNothing);
    expect(
      tester.getTopLeft(levelOneTitle).dx - tester.getTopLeft(rootTitle).dx,
      closeTo(15, 0.01),
    );
    expect(
      tester.getTopLeft(levelTwoTitle).dx - tester.getTopLeft(levelOneTitle).dx,
      closeTo(15, 0.01),
    );
  });

  testWidgets(
    'points list uses location description and hides empty summary row',
    (tester) async {
      await _pumpWorldMap(
        tester,
        users: const [],
        showPointsList: true,
        points: const [
          WorldPoint(
            id: 'summary',
            name: 'Summary Point',
            type: WorldPointType.portal,
            position: _pointPosition,
            users: [],
            description: 'Preferred current summary.',
            locationDescription: 'Older location description.',
          ),
          WorldPoint(
            id: 'empty-location-description',
            name: 'Empty Location Description Point',
            type: WorldPointType.shop,
            position: _pointPosition,
            users: [],
            description: 'Unused summary description.',
          ),
        ],
      );

      expect(find.text('Older location description.'), findsOneWidget);
      expect(find.text('Preferred current summary.'), findsNothing);
      expect(find.text('Unused summary description.'), findsNothing);
      expect(find.byIcon(Icons.schedule), findsNothing);
    },
  );

  testWidgets('points list hands bottom overscroll to details page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final points = List<WorldPoint>.generate(
      18,
      (index) => WorldPoint(
        id: 'point-$index',
        name: 'Location $index',
        type: WorldPointType.portal,
        position: _pointPosition,
        users: const [],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WorldDetailsPageScaffold(
          panelTopGap: 50,
          panelCollapsedHeightOffset: 100,
          map: WorldMap(points: points, showPointsList: true),
          slivers: const [
            SliverToBoxAdapter(
              child: SizedBox(key: ValueKey('details-content'), height: 900),
            ),
          ],
        ),
      ),
    );

    final listView = tester.widget<ListView>(find.byType(ListView));
    expect(listView.padding, const EdgeInsets.fromLTRB(12, 8, 12, 12));

    final detailsTopBefore = tester
        .getTopLeft(find.byKey(const ValueKey('details-content')))
        .dy;

    await tester.drag(find.byType(ListView), const Offset(0, -940));
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -80));
    await tester.pump();

    final detailsTopAfter = tester
        .getTopLeft(find.byKey(const ValueKey('details-content')))
        .dy;
    expect(detailsTopAfter, lessThan(detailsTopBefore));

    final listFinder = find.byType(ListView, skipOffstage: false);
    final listOffsetBefore = tester
        .widget<ListView>(listFinder)
        .controller!
        .offset;

    await tester.drag(listFinder, const Offset(0, 140));
    await tester.pump();

    final listOffsetAfter = tester
        .widget<ListView>(listFinder)
        .controller!
        .offset;
    final detailsTopAfterReturn = tester
        .getTopLeft(find.byKey(const ValueKey('details-content')))
        .dy;
    expect(listOffsetAfter, closeTo(listOffsetBefore, 0.5));
    expect(detailsTopAfterReturn, greaterThan(detailsTopAfter));
  });

  testWidgets('world map preloads next-level location maps', (tester) async {
    await _pumpWorldMap(
      tester,
      mapImageUrl: kMockV1SteamMapImage,
      preloadMapImageUrls: const [
        kMockV1LocationCentralHubMap,
        kMockV1LocationRailGateMap,
      ],
      users: const [],
    );

    expect(
      _assetImageFinder(kMockV1SteamMapImage, skipOffstage: false),
      findsOneWidget,
    );
    expect(
      _assetImageFinder(kMockV1LocationCentralHubMap, skipOffstage: false),
      findsOneWidget,
    );
    expect(
      _assetImageFinder(kMockV1LocationRailGateMap, skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('map taps report branch and leaf locations', (tester) async {
    final tappedIds = <String>[];
    await _pumpWorldMap(
      tester,
      users: const [],
      points: const [
        WorldPoint(
          id: 'root',
          name: 'Root Hub',
          type: WorldPointType.portal,
          position: Offset(0.3, 0.35),
          users: [],
          isLeafLocation: false,
        ),
        WorldPoint(
          id: 'leaf',
          name: 'Leaf Dock',
          type: WorldPointType.shop,
          position: Offset(0.7, 0.35),
          users: [],
        ),
      ],
      onPointTap: (point) => tappedIds.add(point.id),
    );

    await tester.tap(find.text('Root Hub'), warnIfMissed: false);
    expect(tappedIds, ['root']);

    await tester.tap(find.text('Leaf Dock'));
    expect(tappedIds, ['root', 'leaf']);
  });

  testWidgets('drillable map tap does not show a location ripple', (
    tester,
  ) async {
    await _pumpWorldMap(
      tester,
      users: const [],
      points: const [],
      locationNodes: const [
        WorldMapLocationNode(
          id: 'district',
          point: WorldPoint(
            id: 'district',
            sceneId: 'district',
            name: 'Rail District',
            type: WorldPointType.shop,
            position: Offset(0.5, 0.35),
            users: [],
            isLeafLocation: false,
          ),
          children: [
            WorldMapLocationNode(
              id: 'leaf',
              point: WorldPoint(
                id: 'leaf',
                sceneId: 'leaf',
                name: 'Leaf Dock',
                type: WorldPointType.shop,
                position: Offset(0.7, 0.35),
                users: [],
              ),
            ),
            WorldMapLocationNode(
              id: 'leaf-2',
              point: WorldPoint(
                id: 'leaf-2',
                sceneId: 'leaf-2',
                name: 'Signal Room',
                type: WorldPointType.camp,
                position: Offset(0.45, 0.55),
                users: [],
              ),
            ),
          ],
        ),
      ],
      onPointTap: (_) {},
    );

    await tester.tap(find.text('Rail District'), warnIfMissed: false);
    await tester.pump();

    expect(find.text('Leaf Dock'), findsOneWidget);
    expect(find.text('Signal Room'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('world_map_location_tap_ripple')),
      findsNothing,
    );
  });

  testWidgets('world map drills into branch locations internally', (
    tester,
  ) async {
    final tappedIds = <String>[];
    await _pumpWorldMap(
      tester,
      users: const [],
      points: const [],
      locationNodes: const [
        WorldMapLocationNode(
          id: 'root',
          isRoot: true,
          point: WorldPoint(
            id: 'root',
            sceneId: 'root',
            name: 'Root Hub',
            type: WorldPointType.portal,
            position: Offset(0.3, 0.35),
            users: [],
            isLeafLocation: false,
          ),
          children: [
            WorldMapLocationNode(
              id: 'district',
              mapImageUrl: kMockV1LocationCentralHubMap,
              point: WorldPoint(
                id: 'district',
                sceneId: 'district',
                name: 'Rail District',
                type: WorldPointType.shop,
                position: Offset(0.5, 0.35),
                users: [],
                isLeafLocation: false,
              ),
              children: [
                WorldMapLocationNode(
                  id: 'leaf',
                  point: WorldPoint(
                    id: 'leaf',
                    sceneId: 'leaf',
                    name: 'Leaf Dock',
                    type: WorldPointType.shop,
                    position: Offset(0.7, 0.35),
                    users: [],
                  ),
                ),
                WorldMapLocationNode(
                  id: 'leaf-2',
                  point: WorldPoint(
                    id: 'leaf-2',
                    sceneId: 'leaf-2',
                    name: 'Signal Room',
                    type: WorldPointType.camp,
                    position: Offset(0.45, 0.55),
                    users: [],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
      onPointTap: (point) => tappedIds.add(point.id),
    );

    expect(find.text('Root Hub'), findsNothing);
    expect(find.text('Rail District'), findsOneWidget);
    expect(find.byIcon(Icons.subdirectory_arrow_left), findsNothing);

    await tester.tap(find.text('Rail District'), warnIfMissed: false);
    await tester.pump();
    expect(tappedIds, isEmpty);
    expect(find.text('Leaf Dock'), findsOneWidget);
    expect(find.text('Signal Room'), findsOneWidget);
    expect(find.byIcon(Icons.subdirectory_arrow_left), findsOneWidget);
    expect(
      _assetImageFinder(kMockV1LocationCentralHubMap, skipOffstage: false),
      findsWidgets,
    );

    await tester.tap(find.byIcon(Icons.subdirectory_arrow_left));
    await tester.pumpAndSettle();
    expect(find.text('Rail District'), findsOneWidget);
    expect(find.byIcon(Icons.subdirectory_arrow_left), findsNothing);

    await tester.tap(find.text('Rail District'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leaf Dock'));
    expect(tappedIds, ['leaf']);
  });

  testWidgets('world map hides drill exit when showing location list', (
    tester,
  ) async {
    var showPointsList = false;
    late StateSetter setHarnessState;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setHarnessState = setState;
              return SizedBox(
                width: _mapSize.width,
                height: _mapSize.height,
                child: WorldMap(
                  showPointsList: showPointsList,
                  points: const [],
                  locationNodes: const [
                    WorldMapLocationNode(
                      id: 'root',
                      isRoot: true,
                      point: WorldPoint(
                        id: 'root',
                        sceneId: 'root',
                        name: 'Root Hub',
                        type: WorldPointType.portal,
                        position: Offset(0.3, 0.35),
                        users: [],
                        isLeafLocation: false,
                      ),
                      children: [
                        WorldMapLocationNode(
                          id: 'district',
                          point: WorldPoint(
                            id: 'district',
                            sceneId: 'district',
                            name: 'Rail District',
                            type: WorldPointType.shop,
                            position: Offset(0.5, 0.35),
                            users: [],
                            isLeafLocation: false,
                          ),
                          children: [
                            WorldMapLocationNode(
                              id: 'leaf',
                              point: WorldPoint(
                                id: 'leaf',
                                sceneId: 'leaf',
                                name: 'Leaf Dock',
                                type: WorldPointType.shop,
                                position: Offset(0.7, 0.35),
                                users: [],
                              ),
                            ),
                            WorldMapLocationNode(
                              id: 'leaf-2',
                              point: WorldPoint(
                                id: 'leaf-2',
                                sceneId: 'leaf-2',
                                name: 'Signal Room',
                                type: WorldPointType.camp,
                                position: Offset(0.45, 0.55),
                                users: [],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                  onPointTap: (_) {},
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Rail District'), warnIfMissed: false);
    await tester.pump();
    expect(find.byIcon(Icons.subdirectory_arrow_left), findsOneWidget);

    setHarnessState(() {
      showPointsList = true;
    });
    await tester.pump();

    expect(find.byIcon(Icons.subdirectory_arrow_left), findsNothing);
    expect(find.text('Leaf Dock'), findsWidgets);
    expect(find.text('Signal Room'), findsWidgets);
  });

  testWidgets('world map hides root and starts from level two locations', (
    tester,
  ) async {
    await _pumpWorldMap(
      tester,
      users: const [],
      points: const [],
      locationNodes: const [
        WorldMapLocationNode(
          id: 'root',
          isRoot: true,
          point: WorldPoint(
            id: 'root',
            sceneId: 'root',
            name: 'World Root',
            type: WorldPointType.portal,
            position: Offset(0.3, 0.35),
            users: [],
            isLeafLocation: false,
          ),
          children: [
            WorldMapLocationNode(
              id: 'level-2',
              point: WorldPoint(
                id: 'level-2',
                sceneId: 'level-2',
                name: 'Visible District',
                type: WorldPointType.shop,
                position: Offset(0.7, 0.35),
                users: [],
              ),
            ),
          ],
        ),
      ],
    );

    expect(find.text('World Root'), findsNothing);
    expect(find.text('Visible District'), findsOneWidget);
    expect(find.byIcon(Icons.subdirectory_arrow_left), findsNothing);
  });

  testWidgets('world map uses detail map as initial background', (
    tester,
  ) async {
    await _pumpWorldMap(
      tester,
      users: const [],
      points: const [],
      mapImageUrl: kMockV1SteamMapImage,
      locationNodes: const [
        WorldMapLocationNode(
          id: 'root',
          isRoot: true,
          mapImageUrl: kMockV1LocationCentralHubMap,
          point: WorldPoint(
            id: 'root',
            sceneId: 'root',
            name: 'World Root',
            type: WorldPointType.portal,
            position: Offset(0.3, 0.35),
            users: [],
            isLeafLocation: false,
          ),
          children: [
            WorldMapLocationNode(
              id: 'level-2',
              point: WorldPoint(
                id: 'level-2',
                sceneId: 'level-2',
                name: 'Visible District',
                type: WorldPointType.shop,
                position: Offset(0.7, 0.35),
                users: [],
              ),
            ),
          ],
        ),
      ],
    );

    expect(find.text('World Root'), findsNothing);
    expect(find.text('Visible District'), findsOneWidget);
    expect(_assetImageFinder(kMockV1SteamMapImage), findsOneWidget);
    expect(_assetImageFinder(kMockV1LocationCentralHubMap), findsNothing);
  });

  testWidgets('world map opens the only leaf child instead of drilling', (
    tester,
  ) async {
    final tappedIds = <String>[];
    await _pumpWorldMap(
      tester,
      users: const [],
      points: const [],
      locationNodes: const [
        WorldMapLocationNode(
          id: 'root',
          isRoot: true,
          point: WorldPoint(
            id: 'root',
            sceneId: 'root',
            name: 'World Root',
            type: WorldPointType.portal,
            position: Offset(0.3, 0.35),
            users: [],
            isLeafLocation: false,
          ),
          children: [
            WorldMapLocationNode(
              id: 'district',
              point: WorldPoint(
                id: 'district',
                sceneId: 'district',
                name: 'District',
                type: WorldPointType.shop,
                position: Offset(0.5, 0.35),
                users: [],
                isLeafLocation: false,
              ),
              children: [
                WorldMapLocationNode(
                  id: 'room',
                  point: WorldPoint(
                    id: 'room',
                    sceneId: 'room',
                    name: 'Only Room',
                    type: WorldPointType.camp,
                    position: Offset(0.6, 0.45),
                    users: [],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
      onPointTap: (point) => tappedIds.add(point.id),
    );

    await tester.tap(find.text('District'));
    expect(tappedIds, ['room']);
    expect(find.byIcon(Icons.subdirectory_arrow_left), findsNothing);
  });

  testWidgets('world map opens level two leaf directly on two-level tree', (
    tester,
  ) async {
    final tappedIds = <String>[];
    await _pumpWorldMap(
      tester,
      users: const [],
      points: const [],
      locationNodes: const [
        WorldMapLocationNode(
          id: 'root',
          isRoot: true,
          point: WorldPoint(
            id: 'root',
            sceneId: 'root',
            name: 'World Root',
            type: WorldPointType.portal,
            position: Offset(0.3, 0.35),
            users: [],
            isLeafLocation: false,
          ),
          children: [
            WorldMapLocationNode(
              id: 'level-2-leaf',
              point: WorldPoint(
                id: 'level-2-leaf',
                sceneId: 'level-2-leaf',
                name: 'Leaf District',
                type: WorldPointType.shop,
                position: Offset(0.5, 0.35),
                users: [],
              ),
            ),
          ],
        ),
      ],
      onPointTap: (point) => tappedIds.add(point.id),
    );

    expect(find.text('World Root'), findsNothing);
    expect(find.text('Leaf District'), findsOneWidget);
    expect(find.byIcon(Icons.subdirectory_arrow_left), findsNothing);

    await tester.tap(find.text('Leaf District'));
    expect(tappedIds, ['level-2-leaf']);
    expect(find.byIcon(Icons.subdirectory_arrow_left), findsNothing);
  });

  testWidgets('world map renders already rootless leaf nodes', (tester) async {
    final tappedIds = <String>[];
    await _pumpWorldMap(
      tester,
      users: const [],
      points: const [],
      locationNodes: const [
        WorldMapLocationNode(
          id: 'level-2-leaf',
          point: WorldPoint(
            id: 'level-2-leaf',
            sceneId: 'level-2-leaf',
            name: 'Rootless Leaf',
            type: WorldPointType.shop,
            position: Offset(0.5, 0.35),
            users: [],
          ),
        ),
      ],
      onPointTap: (point) => tappedIds.add(point.id),
    );

    expect(find.text('Rootless Leaf'), findsOneWidget);
    expect(find.byIcon(Icons.subdirectory_arrow_left), findsNothing);

    await tester.tap(find.text('Rootless Leaf'));
    expect(tappedIds, ['level-2-leaf']);
  });

  testWidgets('world map does not hide unmarked top-level branch nodes', (
    tester,
  ) async {
    await _pumpWorldMap(
      tester,
      users: const [],
      points: const [],
      locationNodes: const [
        WorldMapLocationNode(
          id: 'district',
          point: WorldPoint(
            id: 'district',
            sceneId: 'district',
            name: 'Top District',
            type: WorldPointType.shop,
            position: Offset(0.5, 0.35),
            users: [],
            isLeafLocation: false,
          ),
          children: [
            WorldMapLocationNode(
              id: 'room',
              point: WorldPoint(
                id: 'room',
                sceneId: 'room',
                name: 'Hidden Room',
                type: WorldPointType.camp,
                position: Offset(0.6, 0.45),
                users: [],
              ),
            ),
          ],
        ),
        WorldMapLocationNode(
          id: 'market',
          point: WorldPoint(
            id: 'market',
            sceneId: 'market',
            name: 'Top Market',
            type: WorldPointType.portal,
            position: Offset(0.3, 0.55),
            users: [],
          ),
        ),
      ],
    );

    expect(find.text('Top District'), findsOneWidget);
    expect(find.text('Top Market'), findsOneWidget);
    expect(find.text('Hidden Room'), findsNothing);
    expect(find.byIcon(Icons.subdirectory_arrow_left), findsNothing);
  });

  testWidgets('points list taps report branch and leaf locations', (
    tester,
  ) async {
    final tappedIds = <String>[];
    await _pumpWorldMap(
      tester,
      users: const [],
      showPointsList: true,
      points: const [
        WorldPoint(
          id: 'root',
          name: 'Root Hub',
          type: WorldPointType.portal,
          position: _pointPosition,
          users: [],
          isLeafLocation: false,
        ),
        WorldPoint(
          id: 'leaf',
          name: 'Leaf Dock',
          type: WorldPointType.shop,
          position: _pointPosition,
          users: [],
          depth: 1,
        ),
      ],
      onPointTap: (point) => tappedIds.add(point.id),
    );

    final rootTitle = find.text('Root Hub').last;
    final leafTitle = find.text('Leaf Dock').last;

    await tester.tap(rootTitle, warnIfMissed: false);
    expect(tappedIds, ['root']);

    await tester.tap(leafTitle);
    expect(tappedIds, ['root', 'leaf']);
  });

  testWidgets('tree location list renders level headers and leaf cards', (
    tester,
  ) async {
    final tappedIds = <String>[];
    await _pumpWorldMap(
      tester,
      users: const [],
      showPointsList: true,
      points: const [],
      locationNodes: const [
        WorldMapLocationNode(
          id: 'root',
          isRoot: true,
          point: WorldPoint(
            id: 'root',
            name: 'Blackspire Arcane Academy',
            type: WorldPointType.portal,
            position: _pointPosition,
            users: [],
            isLeafLocation: false,
          ),
          children: [
            WorldMapLocationNode(
              id: 'fortress',
              point: WorldPoint(
                id: 'fortress',
                name: 'Main Fortress',
                type: WorldPointType.shop,
                position: _pointPosition,
                users: [],
                isLeafLocation: false,
              ),
              children: [
                WorldMapLocationNode(
                  id: 'hall',
                  point: WorldPoint(
                    id: 'hall',
                    name: 'Grand Hall',
                    type: WorldPointType.camp,
                    position: _pointPosition,
                    users: [],
                    locationDescription: 'The stained glass hall.',
                  ),
                ),
                WorldMapLocationNode(
                  id: 'classroom',
                  point: WorldPoint(
                    id: 'classroom',
                    name: 'Sorting Classroom',
                    type: WorldPointType.tavern,
                    position: _pointPosition,
                    users: [],
                    locationDescription: 'The classroom waits.',
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
      onPointTap: (point) => tappedIds.add(point.id),
    );

    expect(find.text('- Blackspire Arcane Academy'), findsOneWidget);
    expect(find.text('- Main Fortress'), findsOneWidget);
    expect(find.text('Grand Hall'), findsOneWidget);
    expect(find.text('Sorting Classroom'), findsOneWidget);

    await tester.tap(find.text('Grand Hall'));
    expect(tappedIds, ['hall']);
  });

  testWidgets('single child level three is opened from level two card', (
    tester,
  ) async {
    final tappedIds = <String>[];
    await _pumpWorldMap(
      tester,
      users: const [],
      showPointsList: true,
      points: const [],
      locationNodes: const [
        WorldMapLocationNode(
          id: 'root',
          isRoot: true,
          point: WorldPoint(
            id: 'root',
            name: 'Academy',
            type: WorldPointType.portal,
            position: _pointPosition,
            users: [],
            isLeafLocation: false,
          ),
          children: [
            WorldMapLocationNode(
              id: 'fortress',
              point: WorldPoint(
                id: 'fortress',
                name: 'Main Fortress',
                type: WorldPointType.shop,
                position: _pointPosition,
                users: [],
                isLeafLocation: false,
              ),
              children: [
                WorldMapLocationNode(
                  id: 'hall',
                  point: WorldPoint(
                    id: 'hall',
                    name: 'Grand Hall',
                    type: WorldPointType.camp,
                    position: _pointPosition,
                    users: [],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
      onPointTap: (point) => tappedIds.add(point.id),
    );

    final list = find.byType(ListView);
    expect(
      find.descendant(of: list, matching: find.text('- Academy')),
      findsOneWidget,
    );
    final mainFortressCard = find.descendant(
      of: list,
      matching: find.text('Main Fortress'),
    );
    expect(mainFortressCard, findsOneWidget);
    expect(
      find.descendant(of: list, matching: find.text('Grand Hall')),
      findsNothing,
    );

    await tester.tap(mainFortressCard);
    expect(tappedIds, ['hall']);
  });

  testWidgets('world map ignores duplicate taps while point tap is pending', (
    tester,
  ) async {
    final tappedIds = <String>[];
    final completer = Completer<void>();
    await _pumpWorldMap(
      tester,
      users: const [],
      onPointTap: (point) {
        tappedIds.add(point.id);
        return completer.future;
      },
    );

    await tester.tap(find.text('Gate'));
    await tester.tap(find.text('Gate'));
    expect(tappedIds, ['point-1']);

    completer.complete();
    await tester.pump();
    await tester.tap(find.text('Gate'));
    expect(tappedIds, ['point-1', 'point-1']);
  });

  testWidgets('world map ignores duplicate taps while drilling into location', (
    tester,
  ) async {
    var drillCount = 0;
    await _pumpWorldMap(
      tester,
      users: const [],
      points: const [],
      onDrillIntoLocation: () {
        drillCount += 1;
      },
      locationNodes: const [
        WorldMapLocationNode(
          id: 'district',
          point: WorldPoint(
            id: 'district',
            sceneId: 'district',
            name: 'District',
            type: WorldPointType.shop,
            position: _pointPosition,
            users: [],
            isLeafLocation: false,
          ),
          children: [
            WorldMapLocationNode(
              id: 'room-a',
              point: WorldPoint(
                id: 'room-a',
                sceneId: 'room-a',
                name: 'Room A',
                type: WorldPointType.camp,
                position: Offset(0.45, 0.4),
                users: [],
              ),
            ),
            WorldMapLocationNode(
              id: 'room-b',
              point: WorldPoint(
                id: 'room-b',
                sceneId: 'room-b',
                name: 'Room B',
                type: WorldPointType.camp,
                position: Offset(0.55, 0.5),
                users: [],
              ),
            ),
          ],
        ),
      ],
    );

    await tester.tap(find.text('District'));
    await tester.tap(find.text('District'), warnIfMissed: false);
    expect(drillCount, 1);

    await tester.pump();
    expect(find.text('Room A'), findsOneWidget);
  });

  testWidgets(
    'points list can show full hierarchy while map points stay scoped',
    (tester) async {
      await _pumpWorldMap(
        tester,
        users: const [],
        showPointsList: true,
        points: const [
          WorldPoint(
            id: 'root',
            name: 'Root Gate',
            type: WorldPointType.portal,
            position: _pointPosition,
            users: [],
          ),
        ],
        listPoints: const [
          WorldPoint(
            id: 'root',
            name: 'Root Gate',
            type: WorldPointType.portal,
            position: _pointPosition,
            users: [],
          ),
          WorldPoint(
            id: 'child',
            name: 'Hidden Child',
            type: WorldPointType.shop,
            position: _pointPosition,
            users: [],
            depth: 1,
          ),
        ],
      );

      final list = find.byType(ListView);
      expect(
        find.descendant(of: list, matching: find.text('Root Gate')),
        findsWidgets,
      );
      expect(
        find.descendant(of: list, matching: find.text('Hidden Child')),
        findsWidgets,
      );
    },
  );

  testWidgets('points list includes root when map uses location tree', (
    tester,
  ) async {
    await _pumpWorldMap(
      tester,
      users: const [],
      showPointsList: true,
      points: const [],
      locationNodes: const [
        WorldMapLocationNode(
          id: 'root',
          isRoot: true,
          point: WorldPoint(
            id: 'root',
            name: 'Root Location',
            type: WorldPointType.portal,
            position: _pointPosition,
            users: [],
            isLeafLocation: false,
          ),
          children: [
            WorldMapLocationNode(
              id: 'child',
              point: WorldPoint(
                id: 'child',
                name: 'Child Location',
                type: WorldPointType.shop,
                position: _pointPosition,
                users: [],
                depth: 1,
              ),
            ),
          ],
        ),
      ],
    );

    final list = find.byType(ListView);
    expect(
      find.descendant(of: list, matching: find.text('- Root Location')),
      findsWidgets,
    );
    expect(
      find.descendant(of: list, matching: find.text('Child Location')),
      findsWidgets,
    );
  });
}

const _mapSize = Size(375, 670);
const _pointPosition = Offset(0.5, 0.35);

Future<void> _pumpWorldMap(
  WidgetTester tester, {
  required List<UserAvatar> users,
  Size size = _mapSize,
  String mapImageUrl = '',
  List<String> preloadMapImageUrls = const <String>[],
  bool showPointsList = false,
  List<WorldPoint>? points,
  List<WorldPoint>? listPoints,
  List<WorldMapLocationNode> locationNodes = const <WorldMapLocationNode>[],
  bool fallbackOnEmptyMapUrl = true,
  WorldPointTapCallback? onPointTap,
  VoidCallback? onDrillIntoLocation,
  ValueChanged<bool>? onMapInteractionChanged,
  WorldMapMessageBubble? activeBubble,
}) async {
  tester.view.physicalSize = const Size(430, 820);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: NotificationListener<WorldMapInteractionNotification>(
            onNotification: (notification) {
              onMapInteractionChanged?.call(notification.active);
              return onMapInteractionChanged != null;
            },
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: WorldMap(
                mapImageUrl: mapImageUrl,
                preloadMapImageUrls: preloadMapImageUrls,
                fallbackOnEmptyMapUrl: fallbackOnEmptyMapUrl,
                showPointsList: showPointsList,
                listPoints: listPoints,
                locationNodes: locationNodes,
                activeBubble: activeBubble,
                onDrillIntoLocation: onDrillIntoLocation,
                onPointTap: onPointTap,
                points:
                    points ??
                    [
                      WorldPoint(
                        id: 'point-1',
                        name: 'Gate',
                        type: WorldPointType.portal,
                        position: _pointPosition,
                        users: users,
                      ),
                    ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Finder _assetImageFinder(String path, {bool skipOffstage = true}) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Image &&
        widget.image is AssetImage &&
        (widget.image as AssetImage).assetName == path,
    skipOffstage: skipOffstage,
  );
}

Finder _assetSvgFinder(String path, {bool skipOffstage = true}) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is SvgPicture &&
        widget.bytesLoader is SvgAssetLoader &&
        (widget.bytesLoader as SvgAssetLoader).assetName == path,
    skipOffstage: skipOffstage,
  );
}

Finder _mapPlaceholderFinder({bool skipOffstage = true}) {
  return find.byWidgetPredicate(
    (widget) => widget is ColoredBox && widget.color == const Color(0xFFF3F4F6),
    skipOffstage: skipOffstage,
  );
}
