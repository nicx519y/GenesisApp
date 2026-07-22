import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/tilemap/tilemap_model.dart';
import 'package:genesis_flutter_android/components/tilemap/tilemap_renderer.dart';
import 'package:genesis_flutter_android/components/world_point.dart';
import 'package:genesis_flutter_android/ui/components/genesis_character_avatar.dart';

void main() {
  test('tilemap defaults to dark visual mode', () {
    expect(tilemapDefaultVisualMode, TilemapVisualMode.dark);
  });

  test('tilemap visual modes use the specified light and dark palette', () {
    expect(
      tilemapVisualStyleFor(TilemapVisualMode.light).backgroundColor,
      const Color(0xFFFAFAF8),
    );
    expect(
      tilemapVisualStyleFor(TilemapVisualMode.light).gridLineColor,
      const Color(0xFFD7D6D2),
    );
    expect(
      tilemapVisualStyleFor(TilemapVisualMode.dark).backgroundColor,
      const Color(0xFF37362E),
    );
    expect(
      tilemapVisualStyleFor(TilemapVisualMode.dark).gridLineColor,
      const Color(0xFF2E2D26),
    );
  });

  test('tilemap config uses explicit sparse map bounds', () {
    final config = TilemapConfig.fromTiles(
      id: 'component_map',
      width: 4,
      height: 3,
      tileTypes: _tileTypes,
      tiles: const [
        TilemapCell(x: 0, y: 0, type: 'a'),
        TilemapCell(x: 3, y: 2, type: 'b'),
      ],
    );

    expect(config.id, 'component_map');
    expect(config.width, 4);
    expect(config.height, 3);
    expect(config.tileCount, 2);
    expect(config.baseAssetUrlForTile(config.tiles.first), endsWith('a.png'));
  });

  test('tilemap config rejects unknown tile types', () {
    expect(
      () => TilemapConfig.fromTiles(
        id: 'component_map',
        width: 1,
        height: 1,
        tileTypes: _tileTypes,
        tiles: const [TilemapCell(x: 0, y: 0, type: 'unknown')],
      ),
      throwsA(isA<TilemapConfigException>()),
    );
  });

  test('tilemap config accepts png and webp asset URLs', () {
    final config = TilemapConfig.fromTiles(
      id: 'supported_asset_formats',
      width: 2,
      height: 1,
      tileTypes: const {
        'png': 'https://cdn.example.com/tile/a.png',
        'webp': 'https://cdn.example.com/tile/b.webp',
      },
      tiles: const [
        TilemapCell(x: 0, y: 0, type: 'png'),
        TilemapCell(x: 1, y: 0, type: 'webp'),
      ],
    );

    expect(config.tileTypes.keys, containsAll(<String>['png', 'webp']));
  });

  test('tilemap config rejects duplicate and negative coordinates', () {
    expect(
      () => TilemapConfig.fromTiles(
        id: 'component_map',
        width: 1,
        height: 1,
        tileTypes: _tileTypes,
        tiles: const [
          TilemapCell(x: 0, y: 0, type: 'a'),
          TilemapCell(x: 0, y: 0, type: 'b'),
        ],
      ),
      throwsA(isA<TilemapConfigException>()),
    );
    expect(
      () => TilemapConfig.fromTiles(
        id: 'component_map',
        width: 1,
        height: 1,
        tileTypes: _tileTypes,
        tiles: const [TilemapCell(x: -1, y: 0, type: 'a')],
      ),
      throwsA(isA<TilemapConfigException>()),
    );
  });

  test('tilemap config rejects invalid dimensions and out-of-bounds tiles', () {
    expect(
      () => TilemapConfig.fromTiles(
        id: 'component_map',
        width: 0,
        height: 1,
        tileTypes: _tileTypes,
        tiles: const [TilemapCell(x: 0, y: 0, type: 'a')],
      ),
      throwsA(isA<TilemapConfigException>()),
    );
    expect(
      () => TilemapConfig.fromTiles(
        id: 'component_map',
        width: 1,
        height: 1,
        tileTypes: _tileTypes,
        tiles: const [TilemapCell(x: 1, y: 0, type: 'a')],
      ),
      throwsA(isA<TilemapConfigException>()),
    );
  });

  test('tilemap cell exposes optional location interaction', () {
    const locationTile = TilemapCell(
      x: 0,
      y: 0,
      type: 'a',
      locationId: 'loc_1',
    );
    const plainTile = TilemapCell(x: 0, y: 0, type: 'a');

    expect(locationTile.isLocationTile, true);
    expect(plainTile.isLocationTile, false);
  });

  test('tilemap config rejects empty tiles and invalid asset URLs', () {
    expect(
      () => TilemapConfig.fromTiles(
        id: 'component_map',
        width: 1,
        height: 1,
        tileTypes: _tileTypes,
        tiles: const <TilemapCell>[],
      ),
      throwsA(isA<TilemapConfigException>()),
    );
    expect(
      () => TilemapConfig.fromTiles(
        id: 'component_map',
        width: 1,
        height: 1,
        tileTypes: const {'a': 'https://cdn.example.com/tile/a_256_256.webp'},
        tiles: const [TilemapCell(x: 0, y: 0, type: 'a')],
      ),
      throwsA(isA<TilemapConfigException>()),
    );
    expect(
      () => TilemapConfig.fromTiles(
        id: 'component_map',
        width: 1,
        height: 1,
        tileTypes: const {'a': 'https://cdn.example.com/tile/a.jpg'},
        tiles: const [TilemapCell(x: 0, y: 0, type: 'a')],
      ),
      throwsA(isA<TilemapConfigException>()),
    );
    expect(
      () => TilemapConfig.fromTiles(
        id: 'component_map',
        width: 1,
        height: 1,
        tileTypes: const {'a': 'https://cdn.example.com/tile/a_256_256.png'},
        tiles: const [TilemapCell(x: 0, y: 0, type: 'a')],
      ),
      throwsA(isA<TilemapConfigException>()),
    );
  });

  test('projection maps grid coordinates to isometric positions', () {
    const projection = TilemapProjection(
      mapWidth: 32,
      mapHeight: 16,
      tileExtent: 16,
      originX: 8,
    );

    expect(
      projection.topLeftForTile(const TilemapCell(x: 1, y: 0, type: 'a')),
      const Offset(16, 4),
    );
  });

  test('projection hit tests the tile diamond', () {
    const projection = TilemapProjection(
      mapWidth: 32,
      mapHeight: 16,
      tileExtent: 16,
      originX: 8,
    );
    const tile = TilemapCell(x: 0, y: 0, type: 'a');

    expect(projection.containsPointInTile(tile, const Offset(8, 4)), true);
    expect(projection.containsPointInTile(tile, const Offset(20, 12)), false);
  });

  test('location bubble offset scales together with its tile', () {
    const projection = TilemapProjection(
      mapWidth: 32,
      mapHeight: 16,
      tileExtent: 16,
      originX: 8,
    );
    const tile = TilemapCell(x: 0, y: 0, type: 'a', locationId: 'loc_1');
    final center = projection.centerForTile(tile);
    final anchor = tilemapLocationBubbleSceneAnchor(projection, tile);

    final normalTransform = tilemapTransformForSceneFocalPoint(
      sceneFocalPoint: Offset.zero,
      viewportFocalPoint: Offset.zero,
      scale: 8,
    );
    final minimumTransform = tilemapTransformForSceneFocalPoint(
      sceneFocalPoint: Offset.zero,
      viewportFocalPoint: Offset.zero,
      scale: 4,
    );

    expect(
      MatrixUtils.transformPoint(normalTransform, anchor).dy -
          MatrixUtils.transformPoint(normalTransform, center).dy,
      16,
    );
    expect(
      MatrixUtils.transformPoint(minimumTransform, anchor).dy -
          MatrixUtils.transformPoint(minimumTransform, center).dy,
      8,
    );
  });

  test('gesture transform keeps the scene focal point stable', () {
    final start = tilemapInitialTransform(
      viewportSize: const Size(320, 640),
      mapSize: const Size(80, 32),
    );
    const focalPoint = Offset(160, 320);
    final scenePoint = MatrixUtils.transformPoint(
      Matrix4.inverted(start),
      focalPoint,
    );

    final transformed = tilemapGestureTransform(
      startTransform: start,
      startFocalPoint: focalPoint,
      currentFocalPoint: focalPoint,
      gestureScale: 2,
    );

    expect(MatrixUtils.transformPoint(transformed, scenePoint), focalPoint);
  });

  test('initial transform fits visible tile width inside screen margins', () {
    const viewportSize = Size(320, 640);
    const contentBounds = Rect.fromLTWH(40, 20, 48, 48);
    final transform = tilemapInitialTransform(
      viewportSize: viewportSize,
      mapSize: const Size(200, 100),
      contentBounds: contentBounds,
    );
    final transformedTopLeft = MatrixUtils.transformPoint(
      transform,
      contentBounds.topLeft,
    );
    final transformedBottomRight = MatrixUtils.transformPoint(
      transform,
      contentBounds.bottomRight,
    );

    expect(tilemapTransformScale(transform), 6);
    expect(transformedTopLeft.dx, tilemapInitialHorizontalMargin);
    expect(
      transformedBottomRight.dx,
      viewportSize.width - tilemapInitialHorizontalMargin,
    );
    expect(
      MatrixUtils.transformPoint(transform, contentBounds.center),
      viewportSize.center(Offset.zero) + const Offset(0, 20),
    );
  });

  test('initial scale follows content width within configured limits', () {
    expect(
      tilemapInitialScaleForContentWidth(viewportWidth: 360, contentWidth: 64),
      5.125,
    );
    expect(
      tilemapInitialScaleForContentWidth(viewportWidth: 360, contentWidth: 128),
      tilemapMinScale,
    );
    expect(
      tilemapInitialScaleForContentWidth(viewportWidth: 360, contentWidth: 8),
      tilemapMaxScale,
    );
  });

  test('gesture scale clamps directly at limits without elastic overflow', () {
    final start = tilemapInitialTransform(
      viewportSize: const Size(320, 640),
      mapSize: const Size(80, 32),
    );
    const focalPoint = Offset(160, 320);

    final maximum = tilemapGestureTransform(
      startTransform: start,
      startFocalPoint: focalPoint,
      currentFocalPoint: focalPoint,
      gestureScale: 100,
    );
    final minimum = tilemapGestureTransform(
      startTransform: start,
      startFocalPoint: focalPoint,
      currentFocalPoint: focalPoint,
      gestureScale: 0.01,
    );

    expect(tilemapTransformScale(maximum), tilemapMaxScale);
    expect(tilemapTransformScale(minimum), tilemapMinScale);
  });

  test('tile URL resolution selects each density tier', () {
    const baseUrl = 'https://cdn.example.com/tile/a.png';

    expect(
      resolveTilemapAssetForDisplaySize(baseUrl, 0),
      'https://cdn.example.com/tile/a.png'
      '?x-oss-process=image/resize,w_128,image/format,webp',
    );
    expect(
      resolveTilemapAssetForDisplaySize(baseUrl, 128),
      'https://cdn.example.com/tile/a.png'
      '?x-oss-process=image/resize,w_128,image/format,webp',
    );
    expect(
      resolveTilemapAssetForDisplaySize(baseUrl, 129),
      'https://cdn.example.com/tile/a.png'
      '?x-oss-process=image/resize,w_256,image/format,webp',
    );
    expect(
      resolveTilemapAssetForDisplaySize(baseUrl, 257),
      'https://cdn.example.com/tile/a.png'
      '?x-oss-process=image/resize,w_512,image/format,webp',
    );
    expect(
      resolveTilemapAssetForDisplaySize(baseUrl, 513),
      'https://cdn.example.com/tile/a.png'
      '?x-oss-process=image/resize,w_1024,image/format,webp',
    );
    expect(
      resolveTilemapAssetForDisplaySize(baseUrl, 2048),
      'https://cdn.example.com/tile/a.png'
      '?x-oss-process=image/resize,w_1024,image/format,webp',
    );
  });

  test('tile URL resolution replaces query and fragment with OSS resize', () {
    expect(
      resolveTilemapAssetForDisplaySize(
        'https://cdn.example.com/tile/a.png?token=abc#preview',
        200,
      ),
      'https://cdn.example.com/tile/a.png'
      '?x-oss-process=image/resize,w_256,image/format,webp',
    );
  });

  test('tile URL resolution supports webp base assets', () {
    expect(
      resolveTilemapAssetForDisplaySize(
        'https://cdn.example.com/tile/a.webp',
        200,
      ),
      'https://cdn.example.com/tile/a.webp'
      '?x-oss-process=image/resize,w_256,image/format,webp',
    );
  });

  test('tile URL resolution follows the production CDN OSS format', () {
    expect(
      resolveTilemapAssetForDisplaySize(
        'https://cdn-001.worldo.ai/predata/tiles/tile_d_1/L1/tiles/'
        'L1_default__modern__urban_dense__warm_cozy_v4.png'
        '?x-oss-process=image/format,webp',
        512,
      ),
      'https://cdn-001.worldo.ai/predata/tiles/tile_d_1/L1/tiles/'
      'L1_default__modern__urban_dense__warm_cozy_v4.png'
      '?x-oss-process=image/resize,w_512,image/format,webp',
    );
  });

  testWidgets('renderer highlights and dispatches only location tiles', (
    tester,
  ) async {
    TilemapCell? tappedTile;
    final config = TilemapConfig.fromTiles(
      id: 'location_tile',
      width: 1,
      height: 1,
      tileTypes: const {'a': 'https://invalid.example.test/tile/a.png'},
      tiles: const [TilemapCell(x: 0, y: 0, type: 'a', locationId: 'loc_1')],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 480,
          child: TilemapRenderer(
            config: config,
            onTileAction: (tile) async => tappedTile = tile,
            locationNameForTile: (_) => 'High School',
          ),
        ),
      ),
    );
    await tester.pump();

    final grid = find.byKey(const ValueKey<String>('tilemap-grid'));
    final gestureLayer = find.byKey(
      const ValueKey<String>('tilemap-gesture-layer'),
    );
    expect(grid, findsOneWidget);
    expect(tester.getSize(grid), tester.getSize(gestureLayer));
    expect(find.text('High School'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('tile-location-label-0-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('tile-location-pointer-High School')),
      findsOneWidget,
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey<String>('tile-location-pointer-High School')),
      ),
      const Size(8, 6.93),
    );
    final bubbleBody = tester.widget<Container>(
      find.byKey(
        const ValueKey<String>('tile-location-bubble-body-High School'),
      ),
    );
    expect(
      bubbleBody.padding,
      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );

    final tileRect = tester.getRect(
      find.byKey(const ValueKey<String>('tile-0-0')),
    );
    final labelRect = tester.getRect(
      find.byKey(const ValueKey<String>('tile-location-label-0-0')),
    );
    expect(labelRect.top, greaterThan(tileRect.center.dy));
    final tileCenter = tileRect.center + Offset(0, tileRect.height / 4);
    await tester.tapAt(tileCenter);
    await tester.pump();

    expect(tappedTile?.locationId, 'loc_1');
    expect(
      find.byKey(const ValueKey<String>('tile-highlight-0-0')),
      findsOneWidget,
    );
    expect(tilemapLocationHighlightColor, const Color(0xFFFFD54F));
  });

  testWidgets('renderer reports network tile image failures', (tester) async {
    Object? imageError;
    final config = TilemapConfig.fromTiles(
      id: 'network_failure',
      width: 1,
      height: 1,
      tileTypes: const {'a': 'https://invalid.example.test/tile/a.png'},
      tiles: const [TilemapCell(x: 0, y: 0, type: 'a')],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 480,
          child: TilemapRenderer(
            config: config,
            onImageError: (error) => imageError = error,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(imageError, isNotNull);
  });

  testWidgets(
    'location avatars render below the bubble with three per centered row',
    (tester) async {
      final config = TilemapConfig.fromTiles(
        id: 'location_avatars',
        width: 1,
        height: 1,
        tileTypes: const {'a': 'https://invalid.example.test/tile/a.png'},
        tiles: const [TilemapCell(x: 0, y: 0, type: 'a', locationId: 'loc_1')],
      );
      const avatars = <UserAvatar>[
        UserAvatar('AA', id: 'a', name: 'Ada'),
        UserAvatar('BB', id: 'b', name: 'Bert'),
        UserAvatar('CC', id: 'c', name: 'Cara'),
        UserAvatar('DD', id: 'd', name: 'Drew'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 320,
            height: 480,
            child: TilemapRenderer(
              config: config,
              locationNameForTile: (_) => 'June Coffee',
              locationAvatarsForTile: (_) => avatars,
            ),
          ),
        ),
      );
      await tester.pump();

      final bubbleRect = tester.getRect(
        find.byKey(
          const ValueKey<String>('tile-location-bubble-body-June Coffee'),
        ),
      );
      final avatarRects = <Rect>[
        for (final id in const ['a', 'b', 'c', 'd'])
          tester.getRect(
            find.byKey(ValueKey<String>('tilemap-location-avatar-$id')),
          ),
      ];

      expect(avatarRects.first.top, greaterThan(bubbleRect.bottom));
      expect(avatarRects[0].top, avatarRects[1].top);
      expect(avatarRects[1].top, avatarRects[2].top);
      expect(avatarRects[3].top, greaterThan(avatarRects[0].bottom));
      expect(
        avatarRects[0].center.dx + avatarRects[2].center.dx,
        closeTo(bubbleRect.center.dx * 2, 0.01),
      );
      expect(avatarRects[3].center.dx, closeTo(bubbleRect.center.dx, 0.01));
      final avatar = tester.widget<GenesisCharacterAvatar>(
        find.byType(GenesisCharacterAvatar).first,
      );
      expect(
        avatar.boxShadow.any(
          (shadow) =>
              shadow.offset.dy > 0 &&
              shadow.blurRadius >= 10 &&
              shadow.spreadRadius > 0,
        ),
        isTrue,
      );
    },
  );
}

const _tileTypes = <String, String>{
  'a': 'https://cdn.example.com/tile/a.png',
  'b': 'https://cdn.example.com/tile/b.png',
};
