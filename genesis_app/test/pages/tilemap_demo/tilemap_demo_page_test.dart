import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:genesis_flutter_android/pages/tilemap_demo/tilemap_demo_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled demo config parses', () async {
    final config = await TilemapDemoConfig.loadDefault();

    expect(config.id, 'tilemap_demo_01');
    expect(config.width, 16);
    expect(config.height, 16);
    expect(config.tileCount, 256);
    expect(
      config.tileTypes['earth_1'],
      'assets/tilemap/map1/compose/earth_1.png',
    );
    expect(
      config.tileTypes.values,
      everyElement(isNot(contains(RegExp(r'_\d+_\d+\.png$')))),
    );
    expect(
      config.tiles.map((tile) => tile.interaction.clickable),
      everyElement(isTrue),
    );
    final buildingTiles = config.tiles.where(
      (tile) => tile.type.startsWith('building_'),
    );
    expect(buildingTiles.length, 8);
    expect(
      buildingTiles.map((tile) => tile.interaction.transitionToMapAsset),
      everyElement(tilemapDemoMap2RoomsConfigAsset),
    );
  });

  test('bundled alternate map config parses', () async {
    final config = await TilemapDemoConfig.loadAsset(
      tilemapDemoMap2RoomsConfigAsset,
    );

    expect(config.id, 'tilemap_demo_map2_rooms');
    expect(config.width, 5);
    expect(config.height, 4);
    expect(config.tileCount, 12);
    expect(
      config.tileTypes['room_1'],
      'assets/tilemap/map2/compose/room_1.png',
    );
    expect(
      config.tiles.map((tile) => tile.interaction.clickable),
      everyElement(isTrue),
    );
    expect(
      {for (final tile in config.tiles) '${tile.x},${tile.y}'},
      {
        '1,0',
        '2,0',
        '3,0',
        '0,1',
        '1,1',
        '2,1',
        '3,1',
        '1,2',
        '2,2',
        '3,2',
        '4,2',
        '2,3',
      },
    );
    for (var y = 0; y < config.height; y += 1) {
      final row =
          config.tiles
              .where((tile) => tile.y == y)
              .map((tile) => tile.x)
              .toList()
            ..sort();
      expect(row, [
        for (var x = row.first; x <= row.last; x += 1) x,
      ], reason: 'map2 row $y should not have a hollow gap');
    }
  });

  test('bundled L1, L2, and L3 configs parse and form a level chain', () async {
    final expectedConfigs =
        <
          (
            String assetPath,
            String id,
            int width,
            int height,
            int tileCount,
            String mapDirectory,
            String? transitionTarget,
          )
        >[
          (
            tilemapDemoL1ConfigAsset,
            'tilemap_demo_l1',
            5,
            5,
            25,
            'map3',
            tilemapDemoL2ConfigAsset,
          ),
          (
            tilemapDemoL2ConfigAsset,
            'tilemap_demo_l2',
            5,
            5,
            25,
            'map4',
            tilemapDemoL3ConfigAsset,
          ),
          (tilemapDemoL3ConfigAsset, 'tilemap_demo_l3', 3, 3, 9, 'map5', null),
        ];

    for (final expected in expectedConfigs) {
      final config = await TilemapDemoConfig.loadAsset(expected.$1);

      expect(config.id, expected.$2);
      expect(config.width, expected.$3);
      expect(config.height, expected.$4);
      expect(config.tileCount, expected.$5);
      expect(
        config.tileTypes.values,
        everyElement(startsWith('assets/tilemap/${expected.$6}/compose/')),
      );
      expect(
        config.tileTypes.values,
        everyElement(isNot(contains(RegExp(r'_\d+_\d+\.png$')))),
      );
      final transitions = config.tiles
          .map((tile) => tile.interaction.transitionToMapAsset)
          .whereType<String>();
      if (expected.$7 == null) {
        expect(transitions, isEmpty);
      } else {
        expect(transitions, isNotEmpty);
        expect(transitions, everyElement(expected.$7));
      }
    }
  });

  test('allows non-square sparse maps', () {
    final config = _validConfig(width: 2, height: 3);
    (config['tiles'] as List<dynamic>).removeLast();

    final parsed = TilemapDemoConfig.fromJsonMap(config);

    expect(parsed.width, 2);
    expect(parsed.height, 3);
    expect(parsed.tileCount, 5);
  });

  test('rejects unknown tile types', () {
    final config = _validConfig();
    (config['tiles'] as List<dynamic>).first['type'] = 'building_missing';

    expect(
      () => TilemapDemoConfig.fromJsonMap(config),
      throwsA(
        isA<TilemapConfigException>().having(
          (error) => error.message,
          'message',
          contains('Unknown tile type'),
        ),
      ),
    );
  });

  test('allows missing coordinates', () {
    final config = _validConfig();
    (config['tiles'] as List<dynamic>).removeLast();

    final parsed = TilemapDemoConfig.fromJsonMap(config);

    expect(parsed.tileCount, 3);
  });

  test('rejects duplicate coordinates', () {
    final config = _validConfig();
    final tiles = config['tiles'] as List<dynamic>;
    tiles.last = <String, dynamic>{'x': 0, 'y': 0, 'type': 'earth_1'};

    expect(
      () => TilemapDemoConfig.fromJsonMap(config),
      throwsA(
        isA<TilemapConfigException>().having(
          (error) => error.message,
          'message',
          contains('Duplicate tile coordinate'),
        ),
      ),
    );
  });

  test('parses clickable tile interaction config', () {
    final config = _validConfig();
    final parsed = TilemapDemoConfig.fromJsonMap(config);

    expect(parsed.tiles.first.interaction.clickable, isTrue);
    expect(
      parsed.tiles.first.interaction.highlightColor,
      const Color(0xFFFFE45C),
    );
  });

  test('parses tile transition action config', () {
    final config = _validConfig();
    final firstTile =
        (config['tiles'] as List<dynamic>).first as Map<String, dynamic>;
    final interaction = firstTile['interaction'] as Map<String, dynamic>;
    interaction['transitionToMapAsset'] = tilemapDemoMap2RoomsConfigAsset;

    final parsed = TilemapDemoConfig.fromJsonMap(config);

    expect(
      parsed.tiles.first.interaction.transitionToMapAsset,
      tilemapDemoMap2RoomsConfigAsset,
    );
  });

  test('resolves logical tile paths to the smallest non-blurry asset size', () {
    const path = 'assets/tilemap/map1/compose/earth_1.png';

    expect(
      resolveTilemapAssetForDisplaySize(path, 96),
      'assets/tilemap/map1/compose/earth_1_128_128.png',
    );
    expect(
      resolveTilemapAssetForDisplaySize(path, 129),
      'assets/tilemap/map1/compose/earth_1_256_256.png',
    );
    expect(
      resolveTilemapAssetForDisplaySize(path, 900),
      'assets/tilemap/map1/compose/earth_1_1024_1024.png',
    );
    expect(
      resolveTilemapAssetForDisplaySize(path, 1400),
      'assets/tilemap/map1/compose/earth_1_1024_1024.png',
    );
  });

  test('gesture transform supports 32x max scale', () {
    final transform = tilemapGestureTransform(
      startTransform: Matrix4.identity(),
      startFocalPoint: Offset.zero,
      currentFocalPoint: Offset.zero,
      gestureScale: 40,
    );

    expect(tilemapMaxScale, 32);
    expect(tilemapTransformScale(transform), tilemapMaxScale);
  });

  test('gesture transform allows elastic overscale before settling', () {
    final transform = tilemapGestureTransform(
      startTransform: Matrix4.identity(),
      startFocalPoint: Offset.zero,
      currentFocalPoint: Offset.zero,
      gestureScale: 40,
      allowElasticBoundary: true,
    );
    final scale = tilemapTransformScale(transform);

    expect(tilemapMaxElasticScaleFactor, 1.25);
    expect(scale, greaterThan(tilemapMaxScale));
    expect(
      scale,
      lessThanOrEqualTo(tilemapMaxScale * tilemapMaxElasticScaleFactor),
    );
  });

  test(
    'bounded scale transform settles elastic overscale back to max scale',
    () {
      final currentTransform = tilemapGestureTransform(
        startTransform: Matrix4.identity(),
        startFocalPoint: const Offset(20, 30),
        currentFocalPoint: const Offset(120, 130),
        gestureScale: 40,
        allowElasticBoundary: true,
      );
      const focalPoint = Offset(120, 130);
      final focalScenePoint = MatrixUtils.transformPoint(
        Matrix4.inverted(currentTransform),
        focalPoint,
      );

      final settledTransform = tilemapBoundedScaleTransform(
        currentTransform: currentTransform,
        focalPoint: focalPoint,
      );

      expect(
        tilemapTransformScale(currentTransform),
        greaterThan(tilemapMaxScale),
      );
      expect(tilemapTransformScale(settledTransform), tilemapMaxScale);
      expect(
        MatrixUtils.transformPoint(settledTransform, focalScenePoint),
        focalPoint,
      );
    },
  );

  test('gesture transform clamps to min scale', () {
    final transform = tilemapGestureTransform(
      startTransform: Matrix4.identity(),
      startFocalPoint: Offset.zero,
      currentFocalPoint: Offset.zero,
      gestureScale: 0.1,
    );

    expect(tilemapMinScale, 4);
    expect(tilemapTransformScale(transform), tilemapMinScale);
  });

  test('uses fixed projection size for the initial map', () {
    final projection = TilemapProjection.fixed(mapWidth: 8, mapHeight: 8);

    expect(projection.mapWidth, 128);
    expect(projection.mapHeight, 72);
    expect(projection.tileExtent, tilemapBaseTileExtent);
  });

  test('initial transform centers the fixed map at 8x scale', () {
    final transform = tilemapInitialTransform(
      viewportSize: const Size(400, 600),
      mapSize: const Size(128, 72),
    );

    expect(tilemapTransformScale(transform), tilemapInitialScale);
    expect(
      MatrixUtils.transformPoint(transform, const Offset(64, 36)),
      const Offset(200, 300),
    );
  });

  test('initial transform centers sparse tile image bounds', () {
    final transform = tilemapInitialTransform(
      viewportSize: const Size(400, 600),
      mapSize: const Size(72, 44),
      contentBounds: const Rect.fromLTRB(8, -4, 56, 32),
    );

    expect(
      MatrixUtils.transformPoint(transform, const Offset(32, 14)),
      const Offset(200, 300),
    );
  });

  test(
    'projects grid coordinates into 45 degree isometric screen positions',
    () {
      const projection = TilemapProjection(
        mapWidth: 256,
        mapHeight: 192,
        tileExtent: 64,
        originX: 64,
      );

      expect(
        projection.topLeftForTile(const TilemapDemoTile(x: 0, y: 0, type: 'a')),
        const Offset(64, 0),
      );
      expect(
        projection.topLeftForTile(const TilemapDemoTile(x: 1, y: 0, type: 'a')),
        const Offset(96, 16),
      );
      expect(
        projection.topLeftForTile(const TilemapDemoTile(x: 0, y: 1, type: 'a')),
        const Offset(32, 16),
      );
    },
  );

  test('bottom aligns tile image with projected clickable polygon', () {
    const projection = TilemapProjection(
      mapWidth: 256,
      mapHeight: 192,
      tileExtent: 64,
      originX: 64,
    );
    const tile = TilemapDemoTile(x: 1, y: 0, type: 'a');
    final polygon = projection.polygonForTile(tile);
    final imageTopLeft = projection.imageTopLeftForTile(tile);

    expect(imageTopLeft, const Offset(64, -16));
    expect(
      imageTopLeft + const Offset(32, 64),
      polygon.reduce((a, b) => a.dy > b.dy ? a : b),
    );
  });

  test('computes image bounds for sparse projected tiles', () {
    final config = TilemapDemoConfig.fromJsonMap(
      _sparseConfig(
        id: 'tilemap_demo_map2_rooms',
        width: 5,
        height: 4,
        coordinates: _map2RoomCoordinates,
      ),
    );
    final projection = TilemapProjection.fixed(
      mapWidth: config.width,
      mapHeight: config.height,
    );

    expect(
      projection.imageBoundsForTiles(config.tiles),
      const Rect.fromLTRB(8, -4, 56, 32),
    );
  });

  test('hit tests projected tile polygons', () {
    const projection = TilemapProjection(
      mapWidth: 256,
      mapHeight: 192,
      tileExtent: 64,
      originX: 64,
    );
    const tile = TilemapDemoTile(
      x: 1,
      y: 0,
      type: 'a',
      interaction: TilemapTileInteraction(
        clickable: true,
        highlightColor: Color(0xFFFFE45C),
      ),
    );

    expect(
      projection.containsPointInTile(tile, projection.centerForTile(tile)),
      isTrue,
    );
    expect(projection.containsPointInTile(tile, const Offset(10, 10)), isFalse);
  });

  test('gesture transform keeps the scene point under the focal point', () {
    final startTransform = tilemapInitialTransform(
      viewportSize: const Size(400, 600),
      mapSize: const Size(200, 100),
    );
    const startFocalPoint = Offset(120, 220);
    const currentFocalPoint = Offset(140, 260);
    final startScenePoint = MatrixUtils.transformPoint(
      Matrix4.inverted(startTransform),
      startFocalPoint,
    );

    final nextTransform = tilemapGestureTransform(
      startTransform: startTransform,
      startFocalPoint: startFocalPoint,
      currentFocalPoint: currentFocalPoint,
      gestureScale: 2,
    );

    expect(
      MatrixUtils.transformPoint(nextTransform, startScenePoint),
      currentFocalPoint,
    );
  });

  test(
    'transition zoom keeps the selected scene point under the tap point',
    () {
      final startTransform = tilemapInitialTransform(
        viewportSize: const Size(400, 600),
        mapSize: const Size(200, 100),
      );
      const scenePoint = Offset(80, 40);
      const viewportPoint = Offset(180, 260);

      final zoomTransform = tilemapZoomTowardScenePoint(
        currentTransform: startTransform,
        scenePoint: scenePoint,
        viewportPoint: viewportPoint,
      );

      expect(tilemapTransitionZoomTargetScale, 40);
      expect(
        tilemapTransformScale(zoomTransform),
        tilemapTransitionZoomTargetScale,
      );
      expect(
        MatrixUtils.transformPoint(zoomTransform, scenePoint),
        viewportPoint,
      );
    },
  );

  testWidgets('renders tiles from config', (tester) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final config = TilemapDemoConfig.fromJsonMap(_validConfig());

    await tester.pumpWidget(
      MaterialApp(home: TilemapDemoPage(configLoader: () async => config)),
    );
    await tester.pumpAndSettle();

    expect(find.text('tilemap_test'), findsOneWidget);
    expect(find.text('2 x 2 / 4 tiles'), findsOneWidget);
    final gestureLayer = find.byKey(
      const ValueKey<String>('tilemap-demo-gesture-layer'),
    );
    expect(gestureLayer, findsOneWidget);
    expect(tester.getSize(gestureLayer).width, 400);
    expect(tester.getSize(gestureLayer).height, greaterThan(400));
    expect(find.byType(Image), findsNWidgets(4));
    final assetNames = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => (image.image as AssetImage).assetName)
        .toSet();
    expect(assetNames.any((asset) => asset.contains('earth_1_')), isTrue);
    expect(assetNames.any((asset) => asset.contains('earth_2_')), isTrue);
    expect(
      assetNames,
      everyElement(
        matches(
          RegExp(
            r'^assets/tilemap/map1/compose/earth_[12]_(128|256|512|1024)_\1\.png$',
          ),
        ),
      ),
    );
  });

  testWidgets('tap header map id opens picker and switches map', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final configs = <String, TilemapDemoConfig>{
      tilemapDemoConfigAsset: TilemapDemoConfig.fromJsonMap(
        _sparseConfig(id: 'tilemap_demo_01', width: 4, height: 4),
      ),
      tilemapDemoMap2RoomsConfigAsset: TilemapDemoConfig.fromJsonMap(
        _sparseConfig(
          id: 'tilemap_demo_map2_rooms',
          width: 5,
          height: 4,
          coordinates: _map2RoomCoordinates,
        ),
      ),
    };

    await tester.pumpWidget(
      MaterialApp(
        home: TilemapDemoPage(
          configAssetLoader: (assetPath) async => configs[assetPath]!,
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('tilemap_demo_01'));

    expect(find.text('tilemap_demo_01'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('tilemap-demo-map-selector')),
    );
    await _pumpUntilFound(tester, find.text('选择地图'));

    expect(find.text('选择地图'), findsOneWidget);
    expect(find.text('Map1 demo'), findsOneWidget);
    expect(find.text('Map2 rooms'), findsOneWidget);

    await tester.tap(find.text('Map2 rooms'));
    await _pumpUntilFound(tester, find.text('tilemap_demo_map2_rooms'));

    expect(find.text('tilemap_demo_map2_rooms'), findsOneWidget);
    expect(find.text('5 x 4 / 12 tiles'), findsOneWidget);
  });

  testWidgets('tapping a transition tile zooms map1 then switches to map2', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final map1 = TilemapDemoConfig.fromJsonMap(_transitionConfig());
    final map2 = TilemapDemoConfig.fromJsonMap(
      _sparseConfig(
        id: 'tilemap_demo_map2_rooms',
        width: 5,
        height: 4,
        coordinates: _map2RoomCoordinates,
      ),
    );
    final configs = <String, TilemapDemoConfig>{
      tilemapDemoConfigAsset: map1,
      tilemapDemoMap2RoomsConfigAsset: map2,
    };

    await tester.pumpWidget(
      MaterialApp(
        home: TilemapDemoPage(
          configAssetLoader: (assetPath) async => configs[assetPath]!,
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('tilemap_demo_01'));

    final gestureLayer = find.byKey(
      const ValueKey<String>('tilemap-demo-gesture-layer'),
    );
    final gestureTopLeft = tester.getTopLeft(gestureLayer);
    final gestureSize = tester.getSize(gestureLayer);
    final projection = TilemapProjection.fixed(
      mapWidth: map1.width,
      mapHeight: map1.height,
    );
    final matrix = tilemapInitialTransform(
      viewportSize: gestureSize,
      mapSize: Size(projection.mapWidth, projection.mapHeight),
      contentBounds: projection.imageBoundsForTiles(map1.tiles),
    );
    final sceneTapPoint = projection.centerForTile(map1.tiles.first);
    final localTapPoint = MatrixUtils.transformPoint(matrix, sceneTapPoint);

    await tester.tapAt(gestureTopLeft + localTapPoint);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('tilemap_demo_01'), findsOneWidget);

    await _pumpUntilFound(tester, find.text('tilemap_demo_map2_rooms'));

    expect(find.text('tilemap_demo_map2_rooms'), findsOneWidget);
    expect(find.text('5 x 4 / 12 tiles'), findsOneWidget);
  });

  testWidgets('clicking a configured tile shows fading highlight', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final config = TilemapDemoConfig.fromJsonMap(_validConfig());

    await tester.pumpWidget(
      MaterialApp(home: TilemapDemoPage(configLoader: () async => config)),
    );
    await tester.pumpAndSettle();

    final gestureLayer = find.byKey(
      const ValueKey<String>('tilemap-demo-gesture-layer'),
    );
    final gestureTopLeft = tester.getTopLeft(gestureLayer);
    final gestureSize = tester.getSize(gestureLayer);
    final projection = TilemapProjection.fixed(
      mapWidth: config.width,
      mapHeight: config.height,
    );
    final matrix = tilemapInitialTransform(
      viewportSize: gestureSize,
      mapSize: Size(projection.mapWidth, projection.mapHeight),
      contentBounds: projection.imageBoundsForTiles(config.tiles),
    );
    final sceneTapPoint = projection.centerForTile(config.tiles.first);
    final localTapPoint = MatrixUtils.transformPoint(matrix, sceneTapPoint);

    await tester.tapAt(gestureTopLeft + localTapPoint);
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('tile-highlight-0-0')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 950));

    expect(
      find.byKey(const ValueKey<String>('tile-highlight-0-0')),
      findsNothing,
    );
  });
}

Map<String, dynamic> _validConfig({int width = 2, int height = 2}) {
  final tiles = <Map<String, dynamic>>[];
  for (var y = 0; y < height; y += 1) {
    for (var x = 0; x < width; x += 1) {
      tiles.add(<String, dynamic>{
        'x': x,
        'y': y,
        'type': (x + y).isEven ? 'earth_1' : 'earth_2',
        'interaction': <String, dynamic>{
          'clickable': true,
          'highlightColor': '#FFE45C',
        },
      });
    }
  }

  return jsonDecode(
        jsonEncode(<String, dynamic>{
          'protocolVersion': 1,
          'map': <String, dynamic>{
            'id': 'tilemap_test',
            'width': width,
            'height': height,
          },
          'tileTypes': <String, String>{
            'earth_1': 'assets/tilemap/map1/compose/earth_1.png',
            'earth_2': 'assets/tilemap/map1/compose/earth_2.png',
          },
          'tiles': tiles,
        }),
      )
      as Map<String, dynamic>;
}

Map<String, dynamic> _transitionConfig() {
  return jsonDecode(
        jsonEncode(<String, dynamic>{
          'protocolVersion': 1,
          'map': <String, dynamic>{
            'id': 'tilemap_demo_01',
            'width': 2,
            'height': 1,
          },
          'tileTypes': <String, String>{
            'building_1': 'assets/tilemap/map1/compose/building_1.png',
            'earth_1': 'assets/tilemap/map1/compose/earth_1.png',
          },
          'tiles': [
            <String, dynamic>{
              'x': 0,
              'y': 0,
              'type': 'building_1',
              'interaction': <String, dynamic>{
                'clickable': true,
                'highlightColor': '#FFE45C',
                'transitionToMapAsset': tilemapDemoMap2RoomsConfigAsset,
              },
            },
            <String, dynamic>{
              'x': 1,
              'y': 0,
              'type': 'earth_1',
              'interaction': <String, dynamic>{
                'clickable': true,
                'highlightColor': '#FFE45C',
              },
            },
          ],
        }),
      )
      as Map<String, dynamic>;
}

Map<String, dynamic> _sparseConfig({
  required String id,
  required int width,
  required int height,
  bool fillAll = false,
  List<(int, int)>? coordinates,
}) {
  final tileCoordinates =
      coordinates ??
      (fillAll
          ? <(int, int)>[
              for (var y = 0; y < height; y += 1)
                for (var x = 0; x < width; x += 1) (x, y),
            ]
          : <(int, int)>[
              (0, 0),
              (1, 0),
              (0, 1),
              (2, 1),
              (1, 2),
              (math.min(width - 1, 3), height - 1),
            ]);
  return jsonDecode(
        jsonEncode(<String, dynamic>{
          'protocolVersion': 1,
          'map': <String, dynamic>{'id': id, 'width': width, 'height': height},
          'tileTypes': <String, String>{
            'earth_1': 'assets/tilemap/map1/compose/earth_1.png',
            'earth_2': 'assets/tilemap/map1/compose/earth_2.png',
          },
          'tiles': [
            for (var i = 0; i < tileCoordinates.length; i += 1)
              <String, dynamic>{
                'x': tileCoordinates[i].$1,
                'y': tileCoordinates[i].$2,
                'type': i.isEven ? 'earth_1' : 'earth_2',
                'interaction': <String, dynamic>{
                  'clickable': true,
                  'highlightColor': '#FFE45C',
                },
              },
          ],
        }),
      )
      as Map<String, dynamic>;
}

const _map2RoomCoordinates = <(int, int)>[
  (1, 0),
  (2, 0),
  (3, 0),
  (0, 1),
  (1, 1),
  (2, 1),
  (3, 1),
  (1, 2),
  (2, 2),
  (3, 2),
  (4, 2),
  (2, 3),
];

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 20,
}) async {
  for (var i = 0; i < maxPumps; i += 1) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
  final visibleText = tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
      .where((text) => text.isNotEmpty)
      .join(' | ');
  fail('Timed out waiting for $finder. Visible text: $visibleText');
}
